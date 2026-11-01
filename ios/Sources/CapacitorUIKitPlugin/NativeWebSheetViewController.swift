import UIKit
import WebKit
import Capacitor

/// An isolated web document in a real UIKit sheet. It deliberately has no
/// Capacitor bridge. Only scoped actions are delegated to the owning app.
@available(iOS 26.0, *)
final class NativeWebSheetViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, UIAdaptivePresentationControllerDelegate {
    let sheetId = UUID().uuidString
    let sessionId: String
    private let notifyBeforeClose: Bool
    private let closeTimeout: TimeInterval
    private let tintColor: String?
    private let colors: [String: Any]
    private var closeWatchdog: DispatchWorkItem?
    private var dismissalStarted = false
    private var pendingActions = Set<Int>()
    private var closing = false
    var onError: ((JSObject) -> Void)?
    var onAction: ((JSObject) -> Void)?
    private let configuration: InstanceConfiguration
    private let payload: JSObject
    private let closeTitle: String
    private let closeButtonVisible: Bool
    private var webView: WKWebView?
    private var confirmationAnchor: UIView?
    private var timeout: DispatchWorkItem?
    private var ready = false
    private var finished = false
    var onReady: (() -> Void)?
    var onFailure: ((String) -> Void)?
    var onDismiss: ((String) -> Void)?

    init(configuration: InstanceConfiguration, data: JSObject, sessionId: String, title: String, closeTitle: String,
         appearance: String, tintColor: String?, colors: [String: Any], closeButtonVisible: Bool, notifyBeforeClose: Bool, closeTimeout: TimeInterval) {
        self.configuration = configuration
        self.payload = data
        self.sessionId = sessionId
        self.notifyBeforeClose = notifyBeforeClose
        self.closeTimeout = max(0.5, min(closeTimeout, 10))
        self.tintColor = tintColor
        self.colors = colors
        self.closeTitle = closeTitle
        self.closeButtonVisible = closeButtonVisible
        super.init(nibName: nil, bundle: nil)
        self.title = title
        switch appearance {
        case "dark": overrideUserInterfaceStyle = .dark
        case "light": overrideUserInterfaceStyle = .light
        default: overrideUserInterfaceStyle = .unspecified
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Sheets keep dismissal and task actions on opposite sides of one header,
    // including devices whose primary navigation uses the vertical bar.
    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }


    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.requestClose()
        })
        navigationItem.leftBarButtonItem?.accessibilityLabel = closeTitle
        if !closeButtonVisible { navigationItem.leftBarButtonItem = nil }
        if let tintColor, tintColor.range(of: "^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$", options: .regularExpression) != nil {
            navigationController?.navigationBar.tintColor = UIColor(hex: tintColor)
        }

        let config = WKWebViewConfiguration()
        let handler = WebViewAssetHandler(router: CapacitorRouter())
        handler.setAssetPath(configuration.appLocation.path)
        handler.setServerUrl(configuration.serverURL)
        handler.setConfiguration(configuration)
        if let scheme = configuration.localURL.scheme { config.setURLSchemeHandler(handler, forURLScheme: scheme) }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            fail("Invalid sheet data")
            return
        }
        config.userContentController.addUserScript(WKUserScript(source: "window.__nativeWebSheet = \(json);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(self, name: "nativeWebSheet")
        let web = WKWebView(frame: .zero, configuration: config)
        webView = web
        web.navigationDelegate = self
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.translatesAutoresizingMaskIntoConstraints = false
        #if DEBUG
        if #available(iOS 16.4, *) { web.isInspectable = true }
        #endif
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        applyConsumerAppearance(colors)
        let timeout = DispatchWorkItem { [weak self] in self?.fail("Sheet content did not become ready") }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
        web.load(URLRequest(url: configuration.appStartServerURL))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !finished, message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        if ready {
            switch type {
            case "action":
                guard let id = body["requestId"] as? Int, let action = body["action"] as? String,
                      !action.isEmpty, !pendingActions.contains(id) else { return }
                pendingActions.insert(id)
                let data = JSTypes.coerceDictionaryToJSObject(body["data"] as? [AnyHashable: Any]) ?? [:]
                onAction?(["sheetId": sheetId, "sessionId": sessionId, "requestId": id, "action": action, "data": data])
            case "error":
                if let message = body["message"] as? String {
                    onError?(["sheetId": sheetId, "sessionId": sessionId, "message": message])
                }
            case "headerActions": setHeaderActions(body)
            case "confirm": showConfirmation(body)
            case "share": showShare(body)
            case "close": dismissSheet()
            default: break
            }
            return
        }
        if type == "error" { fail("Unable to render sheet content"); return }
        guard type == "ready" else { return }
        applyConsumerAppearance(colors.merging(body) { _, value in value })
        ready = true
        updateHeaderInset()
        timeout?.cancel()
        timeout = nil
        onReady?()
        onReady = nil
    }

    func completeAction(_ requestId: Int, result: JSObject?, error: String?) {
        guard !finished, pendingActions.remove(requestId) != nil else { return }
        reply(requestId, result: result, error: error)
    }

    private func setHeaderActions(_ body: [String: Any]) {
        let actions = body["actions"] as? [[String: Any]] ?? []
        navigationItem.rightBarButtonItems = actions.compactMap { action in
            guard let id = action["id"] as? String, !id.isEmpty,
                  let title = action["title"] as? String, !title.isEmpty else { return nil }
            let item = UIBarButtonItem(title: title, primaryAction: UIAction { [weak self] _ in
                guard let self, !self.finished, !self.closing,
                      let data = try? JSONSerialization.data(withJSONObject: ["id": id]),
                      let json = String(data: data, encoding: .utf8) else { return }
                self.webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('native-web-sheet-header-action', {detail: \(json)}))", completionHandler: nil)
            })
            item.isEnabled = !(action["disabled"] as? Bool ?? false)
            return item
        }
    }

    private func showShare(_ body: [String: Any]) {
        guard let requestId = body["requestId"] as? Int else { return }
        guard presentedViewController == nil else { reply(requestId, result: nil, error: "A presentation is already active"); return }
        var items: [Any] = []
        if let text = body["message"] as? String, !text.isEmpty { items.append(text) }
        if let value = body["url"] as? String {
            guard let url = URL(string: value), ["https", "http"].contains(url.scheme ?? "") else {
                reply(requestId, result: nil, error: "Unsupported share URL"); return
            }
            items.append(url)
        }
        guard !items.isEmpty else { reply(requestId, result: nil, error: "Share content is required"); return }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.setValue(body["title"] as? String ?? "", forKey: "subject")
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        activity.completionWithItemsHandler = { [weak self] _, completed, _, error in
            DispatchQueue.main.async { self?.reply(requestId, result: ["shared": completed], error: error?.localizedDescription) }
        }
        present(activity, animated: true)
    }

    private func reply(_ requestId: Int, result: JSObject?, error: String?) {
        guard !finished else { return }
        var response: JSObject = ["requestId": requestId, "result": result ?? [:]]
        if let error { response["error"] = error }
        guard let data = try? JSONSerialization.data(withJSONObject: response),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('native-web-sheet-result', {detail: \(json)}))", completionHandler: nil)
    }

    private func showConfirmation(_ body: [String: Any]) {
        guard let requestId = body["requestId"] as? Int else { return }
        guard presentedViewController == nil else { reply(requestId, result: nil, error: "A presentation is already active"); return }
        let alert = UIAlertController(title: body["title"] as? String, message: body["message"] as? String, preferredStyle: .actionSheet)
        alert.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        alert.addAction(UIAlertAction(title: body["confirmTitle"] as? String, style: .destructive) { [weak self] _ in
            self?.reply(requestId, result: ["confirmed": true], error: nil)
        })
        alert.addAction(UIAlertAction(title: body["cancelTitle"] as? String, style: .cancel) { [weak self] _ in
            self?.reply(requestId, result: ["confirmed": false], error: nil)
        })
        confirmationAnchor?.removeFromSuperview()
        confirmationAnchor = NativeActionSheetAnchor.make(body["source"] as? [String: Any], in: webView ?? view)
        if confirmationAnchor != nil {
            alert.popoverPresentationController?.permittedArrowDirections = []
            alert.popoverPresentationController?.canOverlapSourceViewRect = true
        }
        alert.popoverPresentationController?.sourceView = confirmationAnchor ?? view
        alert.popoverPresentationController?.sourceRect = confirmationAnchor == nil ? CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1) : .null
        present(alert, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderInset()
    }

    private var previousHeaderInset: CGFloat?

    private func updateHeaderInset() {
        guard ready, !finished else { return }
        // The web viewport is already clipped below the native header.
        let inset: CGFloat = 0
        guard previousHeaderInset != inset else { return }
        previousHeaderInset = inset
        webView?.evaluateJavaScript("document.documentElement.style.setProperty('--native-sheet-header-height', '\(inset)px')", completionHandler: nil)
    }

    private func applyConsumerAppearance(_ options: [String: Any]) {
        func color(_ key: String) -> UIColor? {
            guard let value = options[key] as? String,
                  value.range(of: "^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$", options: .regularExpression) != nil else { return nil }
            return UIColor(hex: value)
        }
        if let background = color("backgroundColor") {
            view.backgroundColor = background
            webView?.backgroundColor = background
            webView?.scrollView.backgroundColor = background
            navigationController?.view.backgroundColor = background
        }
        guard let navigation = navigationController else { return }
        if let tint = color("tintColor") { navigation.navigationBar.tintColor = tint }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        let translucent = options["headerTranslucent"] as? Bool ?? false
        appearance.backgroundEffect = translucent ? UIBlurEffect(style: .systemMaterial) : nil
        appearance.backgroundColor = color("headerBackgroundColor") ?? color("backgroundColor")
        appearance.shadowColor = .clear
        navigation.navigationBar.isTranslucent = translucent
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance
        navigation.navigationBar.compactScrollEdgeAppearance = appearance
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let origin = configuration.appStartServerURL
        decisionHandler(url.scheme == origin.scheme && url.host == origin.host && url.port == origin.port ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error.localizedDescription) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail("Sheet web process terminated") }

    /// The document may flush pending edits, but cannot indefinitely trap users.
    /// A second close request, a script error or the watchdog always dismisses.
    func requestClose(force: Bool = false) {
        guard !finished, !dismissalStarted else { return }
        guard notifyBeforeClose, !force, !closing else { dismissSheet(); return }
        closing = true
        let watchdog = DispatchWorkItem { [weak self] in self?.dismissSheet() }
        closeWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + closeTimeout, execute: watchdog)
        webView?.evaluateJavaScript("window.dispatchEvent(new Event('native-web-sheet-close-request'))") { [weak self] _, error in
            if error != nil { self?.dismissSheet() }
        }
    }

    private func dismissSheet() {
        guard !dismissalStarted else { return }
        dismissalStarted = true
        closeWatchdog?.cancel()
        guard let navigation = navigationController, navigation.presentingViewController != nil else { complete("close"); return }
        navigation.dismiss(animated: true) { [weak self] in self?.complete("close") }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { complete("gesture") }

    private func fail(_ message: String) {
        guard !finished else { return }
        finished = true
        cleanUp()
        let callback = onFailure
        clearCallbacks()
        if let navigation = navigationController, navigation.presentingViewController != nil {
            navigation.dismiss(animated: false) { callback?(message) }
        } else { callback?(message) }
    }

    private func complete(_ role: String) {
        guard !finished else { return }
        finished = true
        cleanUp()
        let callback = onDismiss
        clearCallbacks()
        callback?(role)
    }

    private func cleanUp() {
        timeout?.cancel()
        timeout = nil
        closeWatchdog?.cancel()
        closeWatchdog = nil
        pendingActions.removeAll()
        confirmationAnchor?.removeFromSuperview(); confirmationAnchor = nil
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nativeWebSheet")
        webView?.navigationDelegate = nil
    }

    private func clearCallbacks() { onError = nil; onAction = nil; onReady = nil; onFailure = nil; onDismiss = nil }
}


/// A small native source view matching the initiating web control. Providing the
/// actual control bounds enables UIKit's inline Liquid Glass action sheets.
enum NativeActionSheetAnchor {
    static func make(_ source: [String: Any]?, in container: UIView) -> UIView? {
        guard let source,
              let x = source["x"] as? Double, let y = source["y"] as? Double,
              let width = source["width"] as? Double, let height = source["height"] as? Double,
              let viewportWidth = source["viewportWidth"] as? Double,
              let viewportHeight = source["viewportHeight"] as? Double,
              [x, y, width, height, viewportWidth, viewportHeight].allSatisfy({ $0.isFinite }),
              width > 0, height > 0, viewportWidth > 0, viewportHeight > 0,
              let web = webView(in: container), web.bounds.width > 0, web.bounds.height > 0 else { return nil }
        let scaleX = web.bounds.width / viewportWidth
        let scaleY = web.bounds.height / viewportHeight
        let frame = CGRect(x: x * scaleX, y: y * scaleY, width: width * scaleX, height: height * scaleY).intersection(web.bounds)
        guard !frame.isNull, frame.width > 0, frame.height > 0 else { return nil }
        let anchor = UIView(frame: frame)
        anchor.backgroundColor = .clear
        anchor.isUserInteractionEnabled = false
        anchor.accessibilityElementsHidden = true
        web.addSubview(anchor)
        return anchor
    }
    private static func webView(in container: UIView) -> WKWebView? {
        if let web = container as? WKWebView { return web }
        return container.subviews.lazy.compactMap { webView(in: $0) }.first
    }
}
