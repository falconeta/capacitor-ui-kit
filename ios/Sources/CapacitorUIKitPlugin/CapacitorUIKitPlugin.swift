import Foundation
import UIKit
import Capacitor

struct SimpleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@available(iOS 26.0, *)
@objc(CapacitorUIKitPlugin)
public class CapacitorUIKitPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CapacitorUIKitPlugin"
    public let jsName = "CapacitorUIKit"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "beginTopToolbarTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateTopToolbarTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "finishTopToolbarTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "completeWebSheetAction", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentToast", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismissToast", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismissWebSheet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentActionSheet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentDialog", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismissDialog", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentWebSheet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "initialize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reRender", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "createTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeTabs", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "tabBarSelected", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "createToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setToolbarItems", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showTopToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideTopToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "createTopToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setTopToolbarItems", returnType: CAPPluginReturnPromise)
        
    ]
    private let implementation = CapacitorUIKit()
    private let toasts = NativeToastPresenter()
    private let dialogs = NativeDialogPresenter()
    private var webSheet: NativeWebSheetViewController?
    
    
    override public func load() {
        implementation.createView(delegate: self)
        toasts.onDismiss = { [weak self] event in self?.notifyListeners("onNativeToastDismiss", data: event) }
        toasts.onAction = { [weak self] event in self?.notifyListeners("onNativeToastAction", data: event) }
    }
    
    override public func addListener(_ call: CAPPluginCall) {
        super.addListener(call)
        if ["onTabBarLayoutChange", "onTopToolbarLayoutChange"].contains(call.getString("eventName") ?? "") {
            // A listener may arrive after layout, or while UIKit is creating the tabs.
            DispatchQueue.main.async { [weak self] in
                self?.implementation.publishTabBarLayout()
            }
        }
    }

    @objc func presentActionSheet(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var options = JSTypes.coerceDictionaryToJSObject(call.options) ?? [:]
            options["style"] = "actionSheet"
            let sourceItem = call.getInt("sourceItemTag").flatMap { self.implementation.toolbarItem(tag: $0) }
            if call.getInt("sourceItemTag") != nil && sourceItem == nil {
                call.reject("Native action sheet source item is no longer available"); return
            }
            self.dialogs.present(options, sourceItem: sourceItem, presenter: { [weak self] in self?.bridge?.viewController },
                onPresented: { [weak self] id in self?.notifyListeners("onDialogPresent", data: ["id": id]) },
                resolve: { call.resolve($0) }, reject: { call.reject($0) })
        }
    }

    private func showWebSheet(_ content: NativeWebSheetViewController, navigation: UINavigationController,
                              root: UIViewController, attempt: Int = 0) {
        guard webSheet === content else { return }
        var presenter = root
        while let next = presenter.presentedViewController, !next.isBeingDismissed { presenter = next }
        // A browser or another native cover may be visible over the bridge.
        // Wait for its UIKit transition, and present above the visible controller.
        guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingPresented,
              !presenter.isBeingDismissed, !(presenter is UIAlertController) else {
            guard attempt < 100 else { content.presentationFailed("Native sheet presenter is no longer available"); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak root] in
                guard let self, let root else { return }
                self.showWebSheet(content, navigation: navigation, root: root, attempt: attempt + 1)
            }
            return
        }
        presenter.present(navigation, animated: true) { [weak self] in
            guard self?.webSheet === content else { return }
            self?.notifyListeners("onWebSheetPresent", data: ["sessionId": content.sessionId, "sheetId": content.sheetId])
        }
    }

    @objc func presentDialog(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.dialogs.present(JSTypes.coerceDictionaryToJSObject(call.options) ?? [:], presenter: { [weak self] in self?.bridge?.viewController },
                onPresented: { [weak self] id in self?.notifyListeners("onDialogPresent", data: ["id": id]) },
                resolve: { call.resolve($0) }, reject: { call.reject($0) })
        }
    }

    @objc func dismissDialog(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.dialogs.dismiss(id: call.getString("id") ?? "") { dismissed in call.resolve(["dismissed": dismissed]) }
        }
    }

    @objc func presentToast(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let scene = self.bridge?.viewController?.view.window?.windowScene else { call.reject("Toast scene unavailable"); return }
            var options: JSObject = ["id": call.getString("id") ?? "", "header": call.getString("header") ?? "", "message": call.getString("message") ?? "",
                "duration": call.getDouble("duration") ?? 5000, "swipeGesture": call.getBool("swipeGesture") ?? true,
                "buttons": call.getArray("buttons", JSObject.self) ?? []]
            for key in ["backgroundColor", "textColor", "messageColor"] { if let value = call.getString(key) { options[key] = value } }
            do { try self.toasts.present(options, scene: scene); call.resolve() }
            catch { call.reject(error.localizedDescription) }
        }
    }

    @objc func dismissToast(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.toasts.dismiss(call.getString("id") ?? "", role: call.getString("role") ?? "dismiss")
            call.resolve()
        }
    }

    @objc func completeWebSheetAction(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let sheet = self.webSheet, sheet.sheetId == call.getString("sheetId"), let id = call.getInt("requestId") {
                sheet.completeAction(id, result: call.getObject("result"), error: call.getString("error"))
            }
            call.resolve()
        }
    }

    @objc func dismissWebSheet(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let sheet = self.webSheet, sheet.sessionId == call.getString("sessionId") {
                self.dialogs.dismissCurrent { sheet.requestClose(force: call.getBool("force") ?? false) }
            }
            call.resolve()
        }
    }

    @objc func presentWebSheet(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard self.webSheet == nil else { call.reject("A native web sheet is already open"); return }
            guard let bridge = self.bridge, let presenter = bridge.viewController,
                  let data = call.getObject("data") else {
                call.reject("Native web sheet cannot be presented")
                return
            }
            let content = NativeWebSheetViewController(configuration: bridge.config, data: data,
                sessionId: call.getString("sessionId") ?? UUID().uuidString,
                title: call.getString("title") ?? "", closeTitle: call.getString("closeTitle") ?? "Close",
                appearance: call.getString("appearance") ?? "automatic", tintColor: call.getString("tintColor"),
                colors: ["backgroundColor": call.getString("backgroundColor") as Any,
                         "headerBackgroundColor": call.getString("headerBackgroundColor") as Any,
                         "headerTranslucent": call.getBool("headerTranslucent") as Any],
                closeButtonVisible: call.getBool("closeButtonVisible") ?? true,
                notifyBeforeClose: call.getBool("notifyBeforeClose") ?? false,
                closeTimeout: (call.getDouble("closeTimeout") ?? 3000) / 1000)
            let navigation = UINavigationController(rootViewController: content)
            navigation.overrideUserInterfaceStyle = content.overrideUserInterfaceStyle
            navigation.modalPresentationStyle = .pageSheet
            let detents = call.getArray("detents", String.self) ?? ["large"]
            navigation.sheetPresentationController?.detents = detents.map { $0 == "medium" ? .medium() : .large() }
            if let initial = call.getString("initialDetent") {
                navigation.sheetPresentationController?.selectedDetentIdentifier = initial == "medium" ? .medium : .large
            }
            navigation.sheetPresentationController?.prefersGrabberVisible = call.getBool("grabberVisible") ?? true
            navigation.isModalInPresentation = !(call.getBool("dismissible") ?? true)
            navigation.presentationController?.delegate = content
            content.onAction = { [weak self] event in self?.notifyListeners("onWebSheetAction", data: event) }
            content.onError = { [weak self] event in self?.notifyListeners("onWebSheetError", data: event) }
            self.webSheet = content
            content.onReady = { [weak self, weak presenter, weak navigation] in
                guard let self, let presenter, let navigation else { return }
                self.showWebSheet(content, navigation: navigation, root: presenter)
            }
            content.onFailure = { [weak self] error in self?.webSheet = nil; call.reject(error) }
            let dismissedSessionId = content.sessionId, dismissedSheetId = content.sheetId
            content.onDismiss = { [weak self] role in
                self?.webSheet = nil
                self?.notifyListeners("onWebSheetDismiss", data: ["sessionId": dismissedSessionId, "sheetId": dismissedSheetId, "role": role])
                call.resolve(["role": role])
            }
            // Retain the navigation controller while loading offscreen. UIKit
            // takes ownership on presentation; the closure is cleared on ready.
            let ready = content.onReady
            content.onReady = { [navigation] in _ = navigation; ready?() }
            navigation.loadViewIfNeeded()
            content.loadViewIfNeeded()
        }
    }

    @objc func beginTopToolbarTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            do {
                guard let id = call.getInt("id"), let source = call.getObject("from"), let target = call.getObject("to") else {
                    throw SimpleError(message: "Toolbar transition requires id, from and to")
                }
                let nativeDuration = try self.implementation.beginTopToolbarTransition(id, source: source, target: target,
                    backwards: call.getString("direction") == "back", duration: (call.getDouble("duration") ?? 540) / 1000)
                // UIKit owns its standard spring/morph. Let the web page use
                // the same duration without pausing native material rendering.
                DispatchQueue.main.async {
                    call.resolve(["duration": nativeDuration * 1000, "timing": "native", "topInset": self.implementation.topToolbarTopInset()])
                }
            } catch { call.reject(error.localizedDescription) }
        }
    }

    @objc func updateTopToolbarTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.implementation.updateTopToolbarTransition(call.getInt("id") ?? -1, progress: CGFloat(call.getDouble("progress") ?? 0))
            call.resolve()
        }
    }

    @objc func finishTopToolbarTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.implementation.finishTopToolbarTransition(call.getInt("id") ?? -1, completed: call.getBool("completed") ?? false) { call.resolve() }
        }
    }

    @objc func createTabBar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            do {
                guard let items = call.getArray("items", JSObject.self) else {
                    throw SimpleError(message: "items is missing")
                }
                
                guard let options = call.getObject("options") else {
                    throw SimpleError(message: "options is missing")
                }
                
                let searchBarItem = call.getObject("searchBarItem")
                
                implementation.afterTopToolbarTransition { [self] in
                    do {
                        try implementation.createTabBar(items, options: options, searchBarItem: searchBarItem)
                        call.resolve([:])
                    } catch { call.reject(error.localizedDescription) }
                }
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
    
    @objc func createToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            do {
                guard let items = call.getArray("items", JSObject.self) else {
                    throw SimpleError(message: "items is missing")
                }
                
                guard let options = call.getObject("options") else {
                    throw SimpleError(message: "options is missing")
                }
                
                try implementation.createToolbar(items, options: options)
                call.resolve([:])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
    
    @objc func removeTabs(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.removeTabs()
            call.resolve([:])
            
        }
    }
    
    @objc func initialize(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.initialize()
            call.resolve([:])
            
        }
    }
    
    
    @objc func reRender(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.reRender()
            call.resolve([:])
            
        }
    }
    
    @objc func setToolbarItems(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            do {
                guard let items = call.getArray("items", JSObject.self) else {
                    throw SimpleError(message: "items is missing")
                }
                
                guard let options = call.getObject("options") else {
                    throw SimpleError(message: "options is missing")
                }
                
                try implementation.setToolbarItems(items, options: options)
                call.resolve([:])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
    
    @objc func createTopToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            do {
                guard let items = call.getArray("items", JSObject.self) else {
                    throw SimpleError(message: "items is missing")
                }
                
                guard let options = call.getObject("options") else {
                    throw SimpleError(message: "options is missing")
                }
                
                try implementation.createTopToolbar(items, options: options)
                call.resolve([:])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
    
    @objc func setTopToolbarItems(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            do {
                guard let items = call.getArray("items", JSObject.self) else {
                    throw SimpleError(message: "items is missing")
                }
                
                guard let options = call.getObject("options") else {
                    throw SimpleError(message: "options is missing")
                }
                
                try implementation.setTopToolbarItems(items, options: options)
                call.resolve([:])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
    
    @objc func showTabBar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.showTabBar()
            call.resolve([:])
        }
    }
    
    @objc func hideTabBar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.hideTabBar()
            call.resolve([:])
        }
    }
    
    @objc func tabBarSelected(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            call.resolve(["value": implementation.tabBarSelected() ?? nil ])
        }
    }
    
    @objc func showSearch(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.showSearch()
            call.resolve([:])
        }
    }
    
    @objc func hideSearch(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.hideSearch()
            call.resolve([:])
        }
    }
    
    @objc func showToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.showToolbar()
            call.resolve([:])
        }
    }
    
    @objc func hideToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.hideToolbar()
            call.resolve([:])
        }
    }
    
    @objc func showTopToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.showTopToolbar()
            call.resolve([:])
        }
    }
    
    @objc func hideTopToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.hideTopToolbar()
            call.resolve([:])
        }
    }
}


/// Generic system dialogs. All callbacks and business decisions belong to the host.
@available(iOS 26.0, *)
private final class NativeDialogPresenter: NSObject, UIPopoverPresentationControllerDelegate {
    private var id: String?
    private var alert: UIAlertController?
    private var sourceAnchor: UIView?
    private var sourceItem: UIBarButtonItem?
    private var resolve: ((JSObject) -> Void)?
    private var reject: ((String) -> Void)?
    private var retry: DispatchWorkItem?
    private var allowsBackdrop = false
    private var cancelButtonId: String?

    func present(_ options: JSObject, sourceItem: UIBarButtonItem? = nil, presenter: @escaping () -> UIViewController?,
                 onPresented: @escaping (String) -> Void, resolve: @escaping (JSObject) -> Void,
                 reject: @escaping (String) -> Void) {
        guard id == nil, let requestedId = options["id"] as? String, !requestedId.isEmpty,
              let buttons = options["buttons"] as? [JSObject], !buttons.isEmpty,
              buttons.filter({ $0["role"] as? String == "cancel" }).count <= 1 else {
            reject("Invalid or overlapping native dialog"); return
        }
        id = requestedId
        self.sourceItem = sourceItem
        self.resolve = resolve; self.reject = reject
        allowsBackdrop = options["backdropDismiss"] as? Bool ?? false
        cancelButtonId = buttons.first(where: { $0["role"] as? String == "cancel" })?["id"] as? String
        attempt(options, presenter: presenter, onPresented: onPresented, deadline: Date().addingTimeInterval(10))
    }

    private func attempt(_ options: JSObject, presenter: @escaping () -> UIViewController?,
                         onPresented: @escaping (String) -> Void, deadline: Date) {
        guard let requestedId = id else { return }
        guard let root = presenter(), root.view.window != nil else { fail("Native dialog presenter unavailable"); return }
        var top = root
        while let child = top.presentedViewController { top = child }
        if top is UIAlertController || top.isBeingPresented || top.isBeingDismissed {
            guard Date() < deadline else { fail("Native dialog presenter busy"); return }
            let work = DispatchWorkItem { [weak self] in self?.attempt(options, presenter: presenter, onPresented: onPresented, deadline: deadline) }
            retry = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work); return
        }
        guard let requestedStyle = options["style"] as? String, ["alert", "actionSheet"].contains(requestedStyle) else { fail("Dialog style must be explicit"); return }
        let style: UIAlertController.Style = requestedStyle == "actionSheet" ? .actionSheet : .alert
        let controller = UIAlertController(title: options["title"] as? String, message: options["message"] as? String, preferredStyle: style)
        switch options["appearance"] as? String {
        case "dark": controller.overrideUserInterfaceStyle = .dark
        case "light": controller.overrideUserInterfaceStyle = .light
        default: controller.overrideUserInterfaceStyle = .unspecified
        }
        controller.isModalInPresentation = style == .alert && !allowsBackdrop
        if let tint = options["tintColor"] as? String,
           tint.range(of: "^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$", options: .regularExpression) != nil {
            controller.view.tintColor = UIColor(hex: tint)
        }
        for button in options["buttons"] as? [JSObject] ?? [] {
            guard let buttonId = button["id"] as? String, let title = button["title"] as? String else { continue }
            let role = button["role"] as? String ?? "default"
            let action = UIAlertAction(title: title, style: role == "cancel" ? .cancel : role == "destructive" ? .destructive : .default) { [weak self] _ in
                self?.close(result: ["buttonId": buttonId, "role": role], completion: {})
            }
            action.isEnabled = role == "cancel" || !(button["disabled"] as? Bool ?? false)
            controller.addAction(action)
            if style == .alert && button["preferred"] as? Bool == true && role != "cancel" { controller.preferredAction = action }
        }
        if let sourceItem {
            controller.popoverPresentationController?.sourceItem = sourceItem
        } else {
            sourceAnchor = NativeActionSheetAnchor.make(options["source"] as? [String: Any], in: top.view)
            if sourceAnchor != nil {
                controller.popoverPresentationController?.permittedArrowDirections = []
                controller.popoverPresentationController?.canOverlapSourceViewRect = true
            }
            controller.popoverPresentationController?.sourceView = sourceAnchor ?? top.view
            controller.popoverPresentationController?.sourceRect = sourceAnchor == nil ? CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1) : .null
        }
        controller.popoverPresentationController?.delegate = self
        alert = controller
        top.present(controller, animated: true) { [weak self] in
            guard self?.id == requestedId else { return }; onPresented(requestedId)
        }
    }

    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool { allowsBackdrop || cancelButtonId != nil }
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool { allowsBackdrop || cancelButtonId != nil }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === alert else { return }
        var result: JSObject = ["role": "cancel"]
        if let cancelButtonId { result["buttonId"] = cancelButtonId }
        finish(result)
    }
    func dismiss(id: String, completion: @escaping (Bool) -> Void) {
        guard self.id == id else { completion(false); return }
        close(result: ["role": "dismiss"], completion: { completion(true) })
    }
    func dismissCurrent(completion: @escaping () -> Void) {
        guard id != nil else { completion(); return }
        close(result: ["role": "dismiss"], completion: completion)
    }
    private func close(result: JSObject, completion: @escaping () -> Void) {
        retry?.cancel(); retry = nil
        guard let expectedId = id else { completion(); return }
        let done = { [weak self] in
            if self?.id == expectedId { self?.finish(result) }
            completion()
        }
        guard let alert, alert.presentingViewController != nil else { done(); return }
        if alert.isBeingDismissed, let coordinator = alert.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in done() }
        } else {
            alert.dismiss(animated: true, completion: done)
        }
    }
    private func finish(_ result: JSObject) {
        let callback = resolve; clear(); callback?(result)
    }
    private func fail(_ message: String) { let callback = reject; clear(); callback?(message) }
    private func clear() {
        sourceAnchor?.removeFromSuperview(); sourceAnchor = nil; sourceItem = nil
        retry?.cancel(); retry = nil; id = nil; alert = nil; resolve = nil; reject = nil; cancelButtonId = nil
    }
}
