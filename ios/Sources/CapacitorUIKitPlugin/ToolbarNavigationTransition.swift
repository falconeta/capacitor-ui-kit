import UIKit

/// Uses UIKit's standard navigation transition, including native Liquid Glass
/// morphing. The web lifecycle starts it at willEnter and commits/cancels it once.
@available(iOS 26.0, *)
final class ToolbarNavigationTransition: NSObject, UINavigationControllerDelegate {
    let id: Int
    let navigation: UINavigationController
    let source: UIViewController
    let target: UIViewController
    let sourceLeading: [UIBarButtonItem]
    let sourceTrailing: [UIBarButtonItem]
    let targetLeading: [UIBarButtonItem]
    let targetTrailing: [UIBarButtonItem]
    let sourceVisible: Bool
    let targetVisible: Bool
    var onWillShow: ((Bool, Bool) -> Void)?
    var onComplete: ((Bool) -> Void)?
    private weak var previousDelegate: UINavigationControllerDelegate?
    private let backwards: Bool
    private var immediateVisibility: Bool { !sourceVisible }
    private var requestedCompletion: Bool?
    private var nativeCompleted = false
    private var settled = false
    private var detached = false
    private var completion: (() -> Void)?
    private weak var contentContainer: UIView?
    private var contentAlpha: CGFloat = 1
    private var timedAnimator: ToolbarCommitAnimator?

    init(id: Int, navigation: UINavigationController,
         sourceLeading: [UIBarButtonItem], sourceTrailing: [UIBarButtonItem],
         targetLeading: [UIBarButtonItem], targetTrailing: [UIBarButtonItem],
         sourceVisible: Bool, targetVisible: Bool, backwards: Bool, targetTransparent: Bool) {
        self.id = id
        self.navigation = navigation
        self.source = navigation.topViewController!
        self.target = UIViewController()
        self.sourceLeading = sourceLeading
        self.sourceTrailing = sourceTrailing
        self.targetLeading = targetLeading
        self.targetTrailing = targetTrailing
        self.sourceVisible = sourceVisible
        self.targetVisible = targetVisible
        self.backwards = backwards
        super.init()
        target.view.backgroundColor = .clear
        target.view.isOpaque = false
        source.view.isOpaque = false
        target.navigationItem.hidesBackButton = true
        target.navigationItem.applyTransparentBarBackground(targetTransparent)
        target.navigationItem.leadingItemGroups = targetVisible && !targetLeading.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetLeading, representativeItem: nil)] : []
        target.navigationItem.trailingItemGroups = targetVisible && !targetTrailing.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetTrailing, representativeItem: nil)] : []
        // The tab controller explicitly owns visibility. A second policy on
        // navigation placeholders can hide tabs again during a root replacement.
        source.hidesBottomBarWhenPushed = false
        target.hidesBottomBarWhenPushed = false
    }

    func begin(maxDuration: TimeInterval) -> TimeInterval {
        previousDelegate = navigation.delegate
        if immediateVisibility {
            // Showing a previously absent bar must not slide it in vertically.
            // Disappearance instead uses the native transition to empty items.
            UIView.performWithoutAnimation {
                onWillShow?(true, false)
                source.navigationItem.standardAppearance = target.navigationItem.standardAppearance
                source.navigationItem.scrollEdgeAppearance = target.navigationItem.scrollEdgeAppearance
                source.navigationItem.compactAppearance = target.navigationItem.compactAppearance
                source.navigationItem.compactScrollEdgeAppearance = target.navigationItem.compactScrollEdgeAppearance
                source.navigationItem.leadingItemGroups = targetVisible && !targetLeading.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetLeading, representativeItem: nil)] : []
                source.navigationItem.trailingItemGroups = targetVisible && !targetTrailing.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetTrailing, representativeItem: nil)] : []
                navigation.setNavigationBarHidden(!targetVisible, animated: false)
                navigation.tabBarController?.view.layoutIfNeeded()
            }
            nativeCompleted = true
            return 0
        }
        // A short trailing commit needs an explicit transition duration. UIKit
        // uses the animator's duration for its own navigation bar morph too.
        // Ordinary push/pop keep the standard system animator.
        if maxDuration > 0 && maxDuration < 0.35 {
            timedAnimator = ToolbarCommitAnimator(duration: maxDuration)
        }
        navigation.delegate = self
        navigation.setViewControllers(backwards ? [target, source] : [source], animated: false)
        if backwards { navigation.popViewController(animated: true) }
        else { navigation.pushViewController(target, animated: true) }
        hideTransitionContent()
        return navigation.transitionCoordinator?.transitionDuration ?? 0.35
    }

    private func hideTransitionContent() {
        guard var container = navigation.transitionCoordinator?.containerView else { return }
        // Include sibling wrappers and shadows, but never the navigation root or
        // an ancestor containing the navigation bar (also in vertical layouts).
        while let parent = container.superview,
              parent !== navigation.view,
              parent.isDescendant(of: navigation.view),
              !navigation.navigationBar.isDescendant(of: parent) {
            container = parent
        }
        // The plugin owns bars only. UIKit's default content slide also creates
        // dimming/shadow views; hide that whole content container, not the bars.
        // WebKit has already rendered the page transition underneath it.
        guard container !== navigation.view,
              !navigation.navigationBar.isDescendant(of: container) else { return }
        contentContainer = container
        contentAlpha = container.alpha
        UIView.performWithoutAnimation { container.alpha = 0 }
    }

    private func restoreTransitionContent() {
        if let container = contentContainer {
            UIView.performWithoutAnimation { container.alpha = contentAlpha }
        }
        contentContainer = nil
    }

    func update(_ progress: CGFloat) {
        // UIKit owns the timing and spring of its standard item/background morph.
        // Do not pause its layers: that freezes backdrop sampling and tint updates.
    }

    func finish(_ completed: Bool, resolved: @escaping () -> Void) {
        guard !settled else { resolved(); return }
        if let previous = completion { completion = { previous(); resolved() } }
        else { completion = resolved }
        requestedCompletion = completed
        if nativeCompleted || detached { settle(completed) }
    }

    func detachFromContainer() {
        guard !detached, !settled else { return }
        detached = true
        restoreTransitionContent()
        if navigation.delegate === self { navigation.delegate = previousDelegate }
        if let requestedCompletion { settle(requestedCompletion) }
    }

    private func settle(_ completed: Bool) {
        guard !settled else { return }
        settled = true
        restoreTransitionContent()
        if navigation.delegate === self { navigation.delegate = previousDelegate }
        if detached {
            source.navigationItem.leadingItemGroups = []
            source.navigationItem.trailingItemGroups = []
            target.navigationItem.leadingItemGroups = []
            target.navigationItem.trailingItemGroups = []
        } else if !immediateVisibility {
            let destination = completed ? target : source
            // These controllers model one web transition, not the web history.
            // Drop the temporary source even when the destination is already on
            // top: a hidden-bottom-bar policy below it can keep UIKit's tabs hidden.
            if navigation.viewControllers.count != 1 || navigation.topViewController !== destination {
                UIView.performWithoutAnimation {
                    navigation.setViewControllers([destination], animated: false)
                }
            }
        }
        onComplete?(completed)
        let resolved = completion
        completion = nil
        resolved?()
    }

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        timedAnimator
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Keep the bar's container present while UIKit morphs its items away.
        // onComplete hides the empty bar without a second vertical animation.
        let visible = viewController === target ? targetVisible : sourceVisible
        navigationController.setNavigationBarHidden(!(visible || (animated && sourceVisible)), animated: false)
        if animated { onWillShow?(viewController === target, true) }
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        guard !settled, !detached, viewController === target else { return }
        nativeCompleted = true
        restoreTransitionContent()
        if let requestedCompletion { settle(requestedCompletion) }
    }
}

/// The web page is already at its destination. Animate only the transparent
/// native placeholder; UIKit continues to draw and morph its navigation items.
@available(iOS 26.0, *)
private final class ToolbarCommitAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration: TimeInterval
    init(duration: TimeInterval) { self.duration = duration }
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { duration }
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let controller = context.viewController(forKey: .to), let view = context.view(forKey: .to) else {
            context.completeTransition(false)
            return
        }
        view.frame = context.finalFrame(for: controller)
        context.containerView.addSubview(view)
        view.alpha = 0
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
            view.alpha = 1
        }, completion: { _ in context.completeTransition(!context.transitionWasCancelled) })
    }
}

@available(iOS 26.0, *)
extension UINavigationItem {
    func applyTransparentBarBackground(_ transparent: Bool) {
        let appearance: UINavigationBarAppearance?
        if transparent {
            let clear = UINavigationBarAppearance()
            clear.configureWithTransparentBackground()
            appearance = clear
        } else { appearance = nil }
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
        compactAppearance = appearance
        compactScrollEdgeAppearance = appearance
    }
}
