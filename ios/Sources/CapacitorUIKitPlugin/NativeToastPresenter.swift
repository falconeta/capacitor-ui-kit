import UIKit
import Capacitor

@available(iOS 26.0, *)
private final class ToastOverlayWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self || hit === rootViewController?.view ? nil : hit
    }
}

@available(iOS 26.0, *)
private final class ToastOverlayController: UIViewController {
    let stack = UIStackView()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let width = stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -32)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 560), width
        ])
    }
}

@available(iOS 26.0, *)
private final class NativeToastCard: UIView {
    var onSwipe: (() -> Void)?
    @objc private func swiped() { onSwipe?() }
    func enableSwipe() {
        for direction: UISwipeGestureRecognizer.Direction in [.up, .down] {
            let gesture = UISwipeGestureRecognizer(target: self, action: #selector(swiped))
            gesture.direction = direction
            addGestureRecognizer(gesture)
        }
    }
}

/// Uses a non-key window so a banner stays above presented controllers without
/// stealing keyboard focus. Only the cards intercept touches.
@available(iOS 26.0, *)
final class NativeToastPresenter {
    private struct Entry {
        let card: NativeToastCard
        let timer: DispatchWorkItem?
    }
    private var window: ToastOverlayWindow?
    private var controller: ToastOverlayController?
    private var entries: [String: Entry] = [:]
    var onDismiss: ((JSObject) -> Void)?
    var onAction: ((JSObject) -> Void)?

    func present(_ options: JSObject, scene: UIWindowScene) throws {
        guard let id = options["id"] as? String else { throw SimpleError(message: "Toast id is required") }
        if entries[id] != nil { dismiss(id, role: "replaced") }
        if window == nil {
            let controller = ToastOverlayController()
            let window = ToastOverlayWindow(windowScene: scene)
            window.rootViewController = controller
            window.backgroundColor = .clear
            window.windowLevel = .alert + 1
            self.window = window
            self.controller = controller
            window.isHidden = false
        }
        guard let controller else { throw SimpleError(message: "Toast surface unavailable") }
        let card = NativeToastCard()
        card.accessibilityIdentifier = "native-toast-\(id)"
        let background = color(options["backgroundColor"], fallback: .secondarySystemBackground)
        let foreground = color(options["textColor"], fallback: .label)
        card.backgroundColor = background
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.14
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 4
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        let header = options["header"] as? String ?? ""
        let message = options["message"] as? String ?? ""
        for (text, bold, tint) in [(header, true, foreground), (message, false, color(options["messageColor"], fallback: foreground))] where !text.isEmpty {
            let label = UILabel()
            label.text = text
            label.textColor = tint
            label.numberOfLines = 0
            let font = UIFont.preferredFont(forTextStyle: .subheadline)
            label.font = bold ? UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor, size: 0) : font
            label.adjustsFontForContentSizeCategory = true
            content.addArrangedSubview(label)
        }
        let buttons = options["buttons"] as? [JSObject] ?? []
        if !buttons.isEmpty {
            let actions = UIStackView()
            actions.spacing = 12
            actions.distribution = .fillProportionally
            for (index, button) in buttons.enumerated() {
                let control = UIButton(type: .system)
                control.setTitle(button["text"] as? String ?? "", for: .normal)
                control.tintColor = foreground
                control.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
                control.titleLabel?.adjustsFontForContentSizeCategory = true
                control.addAction(UIAction { [weak self] _ in self?.onAction?(["id": id, "index": index]) }, for: .touchUpInside)
                actions.addArrangedSubview(control)
            }
            content.addArrangedSubview(actions)
        } else {
            card.isAccessibilityElement = true
            card.accessibilityLabel = [header, message].filter { !$0.isEmpty }.joined(separator: ". ")
            card.accessibilityTraits = .staticText
        }
        card.onSwipe = { [weak self] in self?.dismiss(id, role: "gesture") }
        if options["swipeGesture"] as? Bool ?? true { card.enableSwipe() }
        let duration = max(0, (options["duration"] as? Double ?? 5000) / 1000)
        let timer = duration > 0 ? DispatchWorkItem { [weak self] in self?.dismiss(id, role: "timeout") } : nil
        entries[id] = Entry(card: card, timer: timer)
        controller.stack.addArrangedSubview(card)
        controller.view.layoutIfNeeded()
        if !UIAccessibility.isReduceMotionEnabled {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: -8)
            UIView.animate(withDuration: 0.22) { card.alpha = 1; card.transform = .identity }
        }
        if let timer { DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: timer) }
        UIAccessibility.post(notification: .announcement, argument: [header, message].filter { !$0.isEmpty }.joined(separator: ". "))
    }

    func dismiss(_ id: String, role: String = "dismiss") {
        guard let entry = entries.removeValue(forKey: id) else { return }
        entry.timer?.cancel()
        let finish = { [weak self] in
            guard let self else { return }
            self.controller?.stack.removeArrangedSubview(entry.card)
            entry.card.removeFromSuperview()
            if self.entries.isEmpty {
                self.window?.isHidden = true
                self.window?.rootViewController = nil
                self.window = nil
                self.controller = nil
            }
            self.onDismiss?(["id": id, "role": role])
        }
        if UIAccessibility.isReduceMotionEnabled { finish() }
        else { UIView.animate(withDuration: 0.18, animations: { entry.card.alpha = 0 }, completion: { _ in finish() }) }
    }

    private func color(_ value: Any?, fallback: UIColor) -> UIColor {
        guard let value = value as? String,
              value.range(of: "^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$", options: .regularExpression) != nil else { return fallback }
        return UIColor(hex: value)
    }
}
