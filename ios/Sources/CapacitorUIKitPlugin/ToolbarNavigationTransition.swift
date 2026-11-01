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
    private let sourceTabsVisible: Bool
    private let targetTabsVisible: Bool
    private var immediateVisibility: Bool { !sourceVisible }
    private var requestedCompletion: Bool?
    private var nativeCompleted = false
    private var settled = false
    private var detached = false
    private var completion: (() -> Void)?
    private weak var contentContainer: UIView?
    private var contentAlpha: CGFloat = 1

    init(id: Int, navigation: UINavigationController,
         sourceLeading: [UIBarButtonItem], sourceTrailing: [UIBarButtonItem],
         targetLeading: [UIBarButtonItem], targetTrailing: [UIBarButtonItem],
         sourceVisible: Bool, targetVisible: Bool, backwards: Bool,
         sourceTabsVisible: Bool, targetTabsVisible: Bool) {
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
        self.sourceTabsVisible = sourceTabsVisible
        self.targetTabsVisible = targetTabsVisible
        super.init()
        target.view.backgroundColor = .clear
        target.view.isOpaque = false
        source.view.isOpaque = false
        target.navigationItem.hidesBackButton = true
        target.navigationItem.leadingItemGroups = targetVisible && !targetLeading.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetLeading, representativeItem: nil)] : []
        target.navigationItem.trailingItemGroups = targetVisible && !targetTrailing.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetTrailing, representativeItem: nil)] : []
        source.hidesBottomBarWhenPushed = !sourceTabsVisible
        target.hidesBottomBarWhenPushed = !targetTabsVisible
    }

    func begin() -> TimeInterval {
        previousDelegate = navigation.delegate
        if immediateVisibility {
            // Showing a previously absent bar must not slide it in vertically.
            // Disappearance instead uses the native transition to empty items.
            UIView.performWithoutAnimation {
                source.hidesBottomBarWhenPushed = !targetTabsVisible
                onWillShow?(true, false)
                source.navigationItem.leadingItemGroups = targetVisible && !targetLeading.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetLeading, representativeItem: nil)] : []
                source.navigationItem.trailingItemGroups = targetVisible && !targetTrailing.isEmpty ? [UIBarButtonItemGroup(barButtonItems: targetTrailing, representativeItem: nil)] : []
                navigation.setNavigationBarHidden(!targetVisible, animated: false)
                navigation.tabBarController?.view.layoutIfNeeded()
            }
            nativeCompleted = true
            return 0
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
        } else if immediateVisibility {
            source.hidesBottomBarWhenPushed = !(completed ? targetTabsVisible : sourceTabsVisible)
        } else {
            let destination = completed ? target : source
            if navigation.topViewController !== destination {
                navigation.setViewControllers([destination], animated: false)
            }
        }
        onComplete?(completed)
        let resolved = completion
        completion = nil
        resolved?()
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
