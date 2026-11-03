import Foundation
import Capacitor
import UIKit

/// Native controls receive touches; the rest of the overlay remains transparent to WebKit.
@available(iOS 26.0, *)
final class PassthroughView: UIView {
    weak var tabController: CapUITabBarController?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event), hit !== self else { return nil }
        var ancestor: UIView? = hit
        while let view = ancestor, view !== self {
            if view is UIControl { return hit }
            if view is UIToolbar || view is UINavigationBar { return nil }
            if view is UITabBar || view is UISearchBar || view is UISearchTextField ||
                view is UITableView || view is UICollectionView {
                return hit
            }
            ancestor = view.superview
        }
        // The system sidebar may use collection views rather than a UITabBar.
        if let controller = tabController, controller.hasVisibleNativeBars {
            let contentFrame = controller.view.convert(controller.contentLayoutGuide.layoutFrame, to: self)
            if !contentFrame.isEmpty && !contentFrame.contains(point) && hit !== controller.view {
                return hit
            }
        }
        return nil
    }
}
    
/// Additional occlusion beyond the system safe area, in physical view coordinates.
struct TabBarContentInsets: Equatable {
    var top: CGFloat = 0
    var right: CGFloat = 0
    var bottom: CGFloat = 0
    var left: CGFloat = 0

    init() {}

    init(bounds: CGRect, content: CGRect, safeArea: UIEdgeInsets, visible: Bool) {
        guard visible, !bounds.isEmpty, !content.isEmpty else { return }
        top = max(0, content.minY - bounds.minY - safeArea.top).rounded(.up)
        right = max(0, bounds.maxX - content.maxX - safeArea.right).rounded(.up)
        bottom = max(0, bounds.maxY - content.maxY - safeArea.bottom).rounded(.up)
        left = max(0, content.minX - bounds.minX - safeArea.left).rounded(.up)
    }

    var data: JSObject {
        ["top": Double(top), "right": Double(right), "bottom": Double(bottom), "left": Double(left)]
    }
}

@available(iOS 26, *)
class CapUITabBarController: UITabBarController, UITabBarControllerDelegate {
    
    weak var pluginDelegate: CapacitorUIKitPlugin?
    var search: UISearchTab?
    private var toolbar: UIToolbar?
    private var topToolbar: UIToolbar?
    private var topToolbarConstraints: [NSLayoutConstraint] = []
    private weak var managedNavigationController: UINavigationController?
    private var adaptiveTopToolbar = false
    private var updatingPageItems = false
    private var navigationTransition: ToolbarNavigationTransition?
    private var deferredContainerUpdates: [() -> Void] = []
    private var pageToolbarVisible = false
    private var pageToolbarTransparent = false
    private var leadingPageItems: [UIBarButtonItem] = []
    private var trailingPageItems: [UIBarButtonItem] = []
    private var hasAppTabs = false
    private var previousTopToolbarPlacement: String?
    private var previousTopToolbarEdge: String?
    private var previousTopToolbarInset: CGFloat?
    private var requestedTabBarVisible = true
    private var placement = "automatic"
    private var previousInsets: TabBarContentInsets?
    private var previousPlacement: String?
    var hasVisibleTabs: Bool { requestedTabBarVisible && hasAppTabs }
    var hasVisibleNativeBars: Bool {
        hasVisibleTabs || (adaptiveTopToolbar && pageToolbarVisible && (!leadingPageItems.isEmpty || !trailingPageItems.isEmpty))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // UITab creates/replaces its navigation container lazily. Restore the
        // current page items once that container exists, including first launch.
        if adaptiveTopToolbar && !updatingPageItems && navigationTransition == nil, let navigation = selectedPageNavigation {
            let visible = pageToolbarVisible && (!leadingPageItems.isEmpty || !trailingPageItems.isEmpty)
            let leading = navigation.topViewController?.navigationItem.leadingItemGroups.flatMap { $0.barButtonItems } ?? []
            let trailing = navigation.topViewController?.navigationItem.trailingItemGroups.flatMap { $0.barButtonItems } ?? []
            if navigation !== managedNavigationController || navigation.isNavigationBarHidden == visible ||
                navigation.topViewController?.hidesBottomBarWhenPushed == true ||
                leading != (visible ? leadingPageItems : []) || trailing != (visible ? trailingPageItems : []) {
                applyManagedPageNavigation()
            }
        }
        publishTabBarLayout()
        publishTopToolbarLayout()
    }

    private var verticalPlacement: String? {
        if #available(iOS 27.1, *) {
            let rightToLeft = traitCollection.layoutDirection == .rightToLeft
            switch traitCollection.verticalBarEdge {
            case .leading: return rightToLeft ? "right" : "left"
            case .trailing: return rightToLeft ? "left" : "right"
            default: break
            }
        }
        return nil
    }

    func publishTabBarLayout(force: Bool = false) {
        // Preparation changes the live bars behind snapshots. Publish only the
        // committed state, so WebKit cannot relayout before its animation starts.
        guard navigationTransition == nil else { return }
        // Do not publish a placeholder before the first set of tabs exists.
        guard hasAppTabs || previousPlacement != nil else { return }
        let insets = TabBarContentInsets(bounds: view.bounds,
                                        content: contentLayoutGuide.layoutFrame,
                                        safeArea: view.safeAreaInsets,
                                        visible: hasVisibleTabs)
        let layout: String
        if !hasVisibleTabs { layout = "hidden" }
        else if placement == "sidebar" && !sidebar.isHidden { layout = "sidebar" }
        else if let vertical = verticalPlacement { layout = vertical }
        else if insets.left > 0 { layout = "left" }
        else if insets.right > 0 { layout = "right" }
        else if insets.top > 0 { layout = "top" }
        else { layout = "bottom" }
        guard force || insets != previousInsets || layout != previousPlacement else { return }
        previousInsets = insets
        previousPlacement = layout
        pluginDelegate?.notifyListeners("onTabBarLayoutChange", data: [
            "placement": layout,
            "insets": insets.data
        ])
    }

    private func updateTabBarVisibility() {
        setTabBarHidden(!hasVisibleTabs, animated: false)
        if placement == "sidebar" {
            sidebar.isHidden = !hasVisibleTabs
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        publishTabBarLayout()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.backgroundColor = .clear
        view.tintAdjustmentMode = .normal
        tabBar.tintAdjustmentMode = .normal
        
        // Remove default background and shadow, make translucent
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.isTranslucent = true
        ensureNavigationContainer()
    }
    
    /// Create and configure tabs based on incoming items + options
    func createTabs(_ items: [UITab], options: JSObject, searchBarItem: JSObject?) throws {
        
        // Extract options
        guard let selectedTag = options["selectedTag"] as? Int else {
            throw SimpleError(message: "selectedTag is missing")
        }
        guard let fontSize = (options["fontSize"] as? NSNumber)?.doubleValue else {
            throw SimpleError(message: "fontSize is missing")
        }
        guard let fontColor = options["fontColor"] as? String else {
            throw SimpleError(message: "fontColor is missing")
        }
        guard let tintColor = options["tintColor"] as? String else {
            throw SimpleError(message: "tintColor is missing")
        }
        guard let unselectedFontSize = (options["unselectedFontSize"] as? NSNumber)?.doubleValue else {
            throw SimpleError(message: "unselectedFontSize is missing")
        }
        guard let unselectedItemTintColor = options["unselectedItemTintColor"] as? String else {
            throw SimpleError(message: "unselectedItemTintColor is missing")
        }
        guard let unselectedFontColor = options["unselectedFontColor"] as? String else {
            throw SimpleError(message: "unselectedFontColor is missing")
        }

        // Opzionali (dark) — se non presenti, fallback su light
        let fontColorDark = options["fontColorDark"] as? String
        let unselectedFontColorDark = options["unselectedFontColorDark"] as? String
        let tintColorDark = options["tintColorDark"] as? String
        let unselectedItemTintColorDark = options["unselectedItemTintColorDark"] as? String


        let requestedPlacement = options["placement"] as? String ?? "automatic"
        guard ["automatic", "sidebar"].contains(requestedPlacement) else {
            throw SimpleError(message: "placement must be automatic or sidebar")
        }
        placement = requestedPlacement
        // Configure tab bar appearance
        let selectedTint = UIColor.dynamic(light: tintColor, dark: tintColorDark)
        let unselectedTint = UIColor.dynamic(light: unselectedItemTintColor, dark: unselectedItemTintColorDark)
        view.tintColor = selectedTint
        tabBar.tintColor = selectedTint
        tabBar.unselectedItemTintColor = UIColor.dynamic(light: unselectedItemTintColor, dark: unselectedItemTintColorDark)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        for itemAppearance in [appearance.stackedLayoutAppearance,
                               appearance.inlineLayoutAppearance,
                               appearance.compactInlineLayoutAppearance] {
            itemAppearance.normal.iconColor = unselectedTint
            itemAppearance.selected.iconColor = selectedTint
            itemAppearance.normal.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: CGFloat(unselectedFontSize)),
                .foregroundColor: UIColor.dynamic(light: unselectedFontColor, dark: unselectedFontColorDark)
            ]
            itemAppearance.selected.titleTextAttributes = [
                .font: UIFont.boldSystemFont(ofSize: CGFloat(fontSize)),
                .foregroundColor: UIColor.dynamic(light: fontColor, dark: fontColorDark)
            ]
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        mode = placement == "sidebar" ? .tabSidebar : .automatic
        if #available(iOS 27.0, *) {
            sidebar.preferredPlacement = placement == "sidebar" ? .sidebar : .automatic
        }
        // UIKit decides when a tab bar is horizontal, vertical, or a sidebar.
        hasAppTabs = !items.isEmpty
        navigationTransition?.detachFromContainer()
        self.setTabs(items, animated: false)
        ensureNavigationContainer()

        if(options["hasSearchBar"] as? Bool ?? false) {
            // Create search tab
            search = UISearchTab { _ in
                let placeholder = searchBarItem?["placeholder"] as? String
                let searchController = UISearchController(searchResultsController: nil)
                searchController.obscuresBackgroundDuringPresentation = false
                searchController.searchBar.placeholder = placeholder ?? ""

                let containerVC = UIViewController()
                containerVC.view.backgroundColor = .clear
                containerVC.navigationItem.searchController = searchController
                containerVC.navigationItem.hidesSearchBarWhenScrolling = false

                let nav = UINavigationController(rootViewController: containerVC)
                nav.view.backgroundColor = .clear

                return nav
            }

            // Append search tab by default
            if let search = search {
                self.tabs.append(search)
                search.automaticallyActivatesSearch = true
            }
        }
        
        
        // Select initial tab based on tag
        if let targetTab = tabs.first(where: { Int($0.identifier) == selectedTag }) {
            self.selectedTab = targetTab
        }
        
        updateTabBarVisibility()
        applyManagedPageNavigation()
    }
    
    func removeTabs() {
        navigationTransition?.detachFromContainer()
        hasAppTabs = false
        self.tabs = []
        ensureNavigationContainer()
        updateTabBarVisibility()
        applyManagedPageNavigation()
    }
    
    func tabBarController(_ tabBarController: UITabBarController,
                          didSelectTab selectedTab: UITab,
                          previousTab: UITab?) {
        if let transition = navigationTransition, selectedPageNavigation !== transition.navigation {
            transition.detachFromContainer()
        }
        applyManagedPageNavigation()
        let tagString = selectedTab.identifier
        guard let tag = Int(tagString) else { return }
        pluginDelegate?.notifyListeners("onTabBarDidSelect", data: ["tag": tag])
    }
    
    /// Called when a tab is selected (legacy API, UITabBarItem)
    func tabBarController(_ tabBarController: UITabBarController,
                          didSelect viewController: UIViewController) {
        if let nav = viewController as? UINavigationController,
           let top = nav.topViewController,
           let searchController = top.navigationItem.searchController {
            DispatchQueue.main.async {
                searchController.isActive = true
                searchController.searchBar.becomeFirstResponder()
            }
        }
    }
    
    func tabBarSelected() -> Int? {
        return selectedTab.flatMap { Int($0.identifier) }
    }
    
    func createToolbar(_ items: JSArray, options: JSObject) throws {
        
        if(toolbar != nil) {
            return
        }
        
        let tb = UIToolbar()
        try tb.setItems(createToolbarItems(from: items, options: options), animated: false)
        
        
        self.toolbar = tb
        
        tb.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonStyle = UIBarButtonItemAppearance()
        buttonStyle.configureWithDefault(for: .plain)
        
        
        
        tb.standardAppearance.prominentButtonAppearance = buttonStyle
        tb.scrollEdgeAppearance?.prominentButtonAppearance = buttonStyle
        
        self.view.addSubview(tb)
        
        NSLayoutConstraint.activate([
            tb.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: 16), // align right with tabBar
            tb.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor, constant: -16), // align right with tabBar
            tb.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -16) // 16pt padding
        ])
    }
    
    func createTopToolbar(_ items: JSArray, options: JSObject) throws {
        if options["adaptive"] as? Bool == true {
            try setManagedPageItems(items, options: options)
            return
        }
        
        if(topToolbar != nil) {
            return
        }
        
        let tb = UIToolbar()
        try tb.setItems(createToolbarItems(from: items, options: options), animated: false)
        
        
        self.topToolbar = tb
        
        tb.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonStyle = UIBarButtonItemAppearance()
        buttonStyle.configureWithDefault(for: .plain)
        
        
        
        tb.standardAppearance.prominentButtonAppearance = buttonStyle
        tb.scrollEdgeAppearance?.prominentButtonAppearance = buttonStyle
        
        self.view.addSubview(tb)
        if let visible = options["visible"] as? Bool {
            pageToolbarVisible = visible
            tb.isHidden = !visible
        }
        layoutTopToolbar(tb, options: options)
        publishTopToolbarLayout()
    }

    // A navigation container is required for UIKit to merge navigation actions
    // with the system's vertical bar on iPhone Duo. Standalone bars do not adapt.
    private func ensureNavigationContainer() {
        guard tabs.isEmpty else { return }
        let page = UITab(title: "", image: nil, identifier: "__native_page__") { _ in
            let content = UIViewController()
            content.view.backgroundColor = .clear
            let navigation = UINavigationController(rootViewController: content)
            navigation.view.backgroundColor = .clear
            navigation.setNavigationBarHidden(true, animated: false)
            return navigation
        }
        setTabs([page], animated: false)
        setTabBarHidden(true, animated: false)
    }

    func afterTopToolbarTransition(_ operation: @escaping () -> Void) {
        if navigationTransition != nil { deferredContainerUpdates.append(operation) }
        else { operation() }
    }

    func beginTopToolbarTransition(_ id: Int, source: JSObject, target: JSObject, backwards: Bool, duration: TimeInterval) throws -> TimeInterval {
        guard navigationTransition == nil else { throw SimpleError(message: "Toolbar transition already active") }
        let sourceItems = source["items"] as? JSArray ?? []
        var sourceOptions = source["options"] as? JSObject ?? [:]
        sourceOptions["animated"] = false
        try setManagedPageItems(sourceItems, options: sourceOptions)
        guard let navigation = selectedPageNavigation, navigation.topViewController != nil else {
            throw SimpleError(message: "Native navigation container unavailable")
        }
        let targetItems = target["items"] as? JSArray ?? []
        let targetOptions = target["options"] as? JSObject ?? [:]
        let sourceTabsVisible = requestedTabBarVisible
        let targetTabsVisible = targetOptions["tabBarVisible"] as? Bool ?? sourceTabsVisible
        let sourceTransparent = pageToolbarTransparent
        let targetTransparent = targetOptions["transparentBackground"] as? Bool ?? false
        let sourceAppearance = overrideUserInterfaceStyle
        let targetAppearance = interfaceStyle(targetOptions["appearance"] as? String)
        let split = targetItems.firstIndex { ($0 as? JSObject)?["type"] as? Int == 1 }
        let leading = try createToolbarItems(from: split.map { Array(targetItems[..<$0]) } ?? [], options: targetOptions)
        let trailing = try createToolbarItems(from: split.map { Array(targetItems[($0 + 1)...]) } ?? targetItems, options: targetOptions)
        let visible = (targetOptions["visible"] as? Bool ?? true) && (!leading.isEmpty || !trailing.isEmpty)
        let transition = ToolbarNavigationTransition(id: id, navigation: navigation,
            sourceLeading: leadingPageItems, sourceTrailing: trailingPageItems,
            targetLeading: leading, targetTrailing: trailing,
            sourceVisible: pageToolbarVisible, targetVisible: visible, backwards: backwards,
            targetTransparent: targetTransparent)
        transition.onWillShow = { [weak self] isTarget, animated in
            guard let self else { return }
            self.overrideUserInterfaceStyle = isTarget ? targetAppearance : sourceAppearance
            self.requestedTabBarVisible = isTarget ? targetTabsVisible : sourceTabsVisible
            self.setTabBarHidden(!self.hasVisibleTabs, animated: animated)
        }
        transition.source.navigationItem.hidesBackButton = true
        transition.onComplete = { [weak self, weak transition] completed in
            guard let self, let transition, self.navigationTransition === transition else { return }
            self.leadingPageItems = completed ? transition.targetLeading : transition.sourceLeading
            self.trailingPageItems = completed ? transition.targetTrailing : transition.sourceTrailing
            self.pageToolbarVisible = completed ? transition.targetVisible : transition.sourceVisible
            self.pageToolbarTransparent = completed ? targetTransparent : sourceTransparent
            self.navigationTransition = nil
            self.overrideUserInterfaceStyle = completed ? targetAppearance : sourceAppearance
            self.requestedTabBarVisible = completed ? targetTabsVisible : sourceTabsVisible
            self.updateTabBarVisibility()
            self.applyManagedPageNavigation()
            self.publishTopToolbarLayout()
            // Preserve the animating navigation container through willEnter /
            // willLeave. Rebuilding tabs mid-flight would reveal items only at
            // completion, after detaching their original UIKit coordinator.
            let operations = self.deferredContainerUpdates
            self.deferredContainerUpdates.removeAll()
            operations.forEach { $0() }
        }
        navigationTransition = transition
        return transition.begin(maxDuration: duration)
    }

    func updateTopToolbarTransition(_ id: Int, progress: CGFloat) {
        guard let transition = navigationTransition, transition.id == id else { return }
        transition.update(progress)
    }

    func finishTopToolbarTransition(_ id: Int, completed: Bool, resolved: @escaping () -> Void) {
        guard let transition = navigationTransition, transition.id == id else { resolved(); return }
        transition.finish(completed, resolved: resolved)
    }

    private func setManagedPageItems(_ items: JSArray, options: JSObject) throws {
        updatingPageItems = true
        defer { updatingPageItems = false }
        adaptiveTopToolbar = true
        pageToolbarTransparent = options["transparentBackground"] as? Bool ?? false
        if let appearance = options["appearance"] as? String {
            overrideUserInterfaceStyle = interfaceStyle(appearance)
        }
        topToolbar?.isHidden = true
        ensureNavigationContainer()
        let split = items.firstIndex { ($0 as? JSObject)?["type"] as? Int == 1 }
        if let split {
            leadingPageItems = try createToolbarItems(from: Array(items[..<split]), options: options)
            trailingPageItems = try createToolbarItems(from: Array(items[(split + 1)...]), options: options)
        } else {
            leadingPageItems = []
            trailingPageItems = try createToolbarItems(from: items, options: options)
        }
        if let visible = options["visible"] as? Bool { pageToolbarVisible = visible }
        let animated = options["animated"] as? Bool ?? false
        if animated && view.window != nil && !UIAccessibility.isReduceMotionEnabled {
            // One persistent native surface: exchange menu and Back without a
            // hide/show gap or exposing the WebView's fallback buttons.
            UIView.transition(with: view, duration: 0.30,
                              options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction]) {
                self.applyManagedPageNavigation()
                self.view.layoutIfNeeded()
            }
        } else {
            applyManagedPageNavigation()
            view.layoutIfNeeded()
        }
        publishTopToolbarLayout()
    }

    private func interfaceStyle(_ value: String?) -> UIUserInterfaceStyle {
        switch value {
        case "light": return .light
        case "dark": return .dark
        default: return .unspecified
        }
    }

    private var selectedPageNavigation: UINavigationController? {
        selectedTab?.viewController as? UINavigationController ?? selectedViewController as? UINavigationController
    }

    private func applyManagedPageNavigation() {
        guard navigationTransition == nil else { return }
        // Static restores (including modal dismissal) must not inherit a parent
        // animation and make the navigation bar slide back in from an edge.
        let wasUpdating = updatingPageItems
        updatingPageItems = true
        UIView.performWithoutAnimation {
            self.applyManagedPageNavigationImmediately()
            self.view.layoutIfNeeded()
        }
        updatingPageItems = wasUpdating
    }

    private func applyManagedPageNavigationImmediately() {
        let target = adaptiveTopToolbar ? selectedPageNavigation : nil
        target?.loadViewIfNeeded()
        // Detach items from the previous tab before attaching them to the new one.
        // UIBarButtonItems must never belong to two navigation item groups at once.
        if let previous = managedNavigationController, previous !== target {
            previous.topViewController?.navigationItem.leadingItemGroups = []
            previous.topViewController?.navigationItem.trailingItemGroups = []
            previous.setNavigationBarHidden(true, animated: false)
        }
        managedNavigationController = target
        guard let navigation = target, let content = navigation.topViewController else { return }
        let visible = pageToolbarVisible && (!leadingPageItems.isEmpty || !trailingPageItems.isEmpty)
        navigation.navigationBar.tintAdjustmentMode = .normal
        // Visibility belongs to setTabBarHidden, not to this synthetic stack.
        // Keeping two UIKit policies can leave tabs hidden after a root replace.
        content.hidesBottomBarWhenPushed = false
        content.navigationItem.applyTransparentBarBackground(pageToolbarTransparent)
        content.navigationItem.leftItemsSupplementBackButton = false
        content.navigationItem.leadingItemGroups = visible && !leadingPageItems.isEmpty ? [UIBarButtonItemGroup(barButtonItems: leadingPageItems, representativeItem: nil)] : []
        content.navigationItem.trailingItemGroups = visible && !trailingPageItems.isEmpty ? [UIBarButtonItemGroup(barButtonItems: trailingPageItems, representativeItem: nil)] : []
        navigation.setNavigationBarHidden(!visible, animated: false)
        view.setNeedsLayout()
    }

    func topToolbarTopInset() -> CGFloat {
        guard adaptiveTopToolbar, let navigation = selectedPageNavigation,
              !navigation.isNavigationBarHidden, let item = navigation.topViewController?.navigationItem else { return 0 }
        let items = (item.leadingItemGroups + item.trailingItemGroups).flatMap { $0.barButtonItems }
        let hasHorizontalItem = items.contains { item in
            if let custom = item.customView, custom.window != nil, !custom.isHidden { return true }
            if #available(iOS 27.1, *) { return item.axisBehavior == .horizontalOnly }
            return false
        }
        guard hasHorizontalItem else { return 0 }
        // A vertical toolbar can coexist with a horizontal text control. Reserve
        // the whole native bar band, including the Glass background's clearance.
        let frame = navigation.navigationBar.convert(navigation.navigationBar.bounds, to: view)
        return max(0, frame.maxY.rounded(.up))
    }

    func publishTopToolbarLayout(force: Bool = false) {
        guard navigationTransition == nil else { return }
        let visible = pageToolbarVisible && (adaptiveTopToolbar ?
            (!leadingPageItems.isEmpty || !trailingPageItems.isEmpty) : topToolbar != nil)
        let placement = visible ? (adaptiveTopToolbar ? (verticalPlacement ?? "top") : "top") : "hidden"
        let edge = verticalPlacement ?? "none"
        let topInset = visible ? topToolbarTopInset() : 0
        guard force || placement != previousTopToolbarPlacement || edge != previousTopToolbarEdge || topInset != previousTopToolbarInset else { return }
        previousTopToolbarPlacement = placement
        previousTopToolbarEdge = edge
        previousTopToolbarInset = topInset
        pluginDelegate?.notifyListeners("onTopToolbarLayoutChange", data: ["placement": placement, "verticalEdge": edge, "topInset": Double(topInset)])
    }

    private func layoutTopToolbar(_ tb: UIToolbar, options: JSObject) {
        NSLayoutConstraint.deactivate(topToolbarConstraints)
        if let position = options["position"] as? JSObject,
           let top = position["top"] as? NSNumber,
           let left = position["left"] as? NSNumber,
           let right = position["right"] as? NSNumber,
           [top, left, right].allSatisfy({ $0.doubleValue.isFinite && $0.doubleValue >= 0 }) {
            topToolbarConstraints = [
                tb.topAnchor.constraint(equalTo: view.topAnchor, constant: CGFloat(top.doubleValue)),
                tb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(left.doubleValue) + 8),
                tb.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(right.doubleValue) - 8)
            ]
        } else {
            topToolbarConstraints = [
                tb.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
                tb.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: 8),
                tb.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor, constant: -8)
            ]
        }
        NSLayoutConstraint.activate(topToolbarConstraints)
        view.layoutIfNeeded()
    }

    func setToolItems(_ items: JSArray, options: JSObject) throws {
        try toolbar?.setItems(createToolbarItems(from: items, options: options), animated: false)
    }

    func setTopToolItems(_ items: JSArray, options: JSObject) throws {
        if options["adaptive"] as? Bool == true {
            try setManagedPageItems(items, options: options)
            return
        }
        if adaptiveTopToolbar {
            adaptiveTopToolbar = false
            applyManagedPageNavigation()
        }
        guard let topToolbar else {
            try createTopToolbar(items, options: options)
            return
        }
        try topToolbar.setItems(createToolbarItems(from: items, options: options), animated: options["animated"] as? Bool ?? false)
        if let visible = options["visible"] as? Bool {
            pageToolbarVisible = visible
            topToolbar.isHidden = !visible
        }
        layoutTopToolbar(topToolbar, options: options)
        publishTopToolbarLayout()
    }

    /// Show the search tab dynamically
    func showSearch() {
        if let search = search, !self.tabs.contains(where: { $0 is UISearchTab }) {
            self.tabs.append(search)
        }
    }
    
    func showToolbar() {
        toolbar?.isHidden = false
    }
    
    func showTopToolbar() {
        pageToolbarVisible = true
        if adaptiveTopToolbar { applyManagedPageNavigation() }
        else { topToolbar?.isHidden = false }
        publishTopToolbarLayout()
    }
    
    /// Hide the search tab dynamically
    func hideSearch() {
        self.tabs.removeAll { $0 is UISearchTab }
    }
    
    func hideToolbar() {
        toolbar?.isHidden = true
    }
    
    func hideTopToolbar() {
        pageToolbarVisible = false
        topToolbar?.isHidden = true
        applyManagedPageNavigation()
        publishTopToolbarLayout()
    }
    
    /// Show tab bar
    func showTabBar() {
        setRequestedTabBarVisible(true)
    }
    
    /// Hide tab bar
    func hideTabBar() {
        setRequestedTabBarVisible(false)
    }
    
    private func setRequestedTabBarVisible(_ visible: Bool) {
        // Requests during page motion must not tear down its captured surface.
        if navigationTransition != nil {
            afterTopToolbarTransition { [weak self] in self?.setRequestedTabBarVisible(visible) }
            return
        }
        guard requestedTabBarVisible != visible else {
            // UIKit may have hidden/recreated a bar while a native cover was up.
            // Reassert the same intent without replaying a fade animation.
            UIView.performWithoutAnimation {
                self.updateTabBarVisibility()
                self.applyManagedPageNavigation()
                self.view.layoutIfNeeded()
            }
            return
        }
        let change = {
            self.requestedTabBarVisible = visible
            self.updateTabBarVisibility()
        }
        if view.window != nil && hasAppTabs && !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(with: view, duration: 0.25,
                              options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction],
                              animations: change)
        } else { change() }
    }

    /// Destroy tab bar and clear controllers
    func destroy() {
        self.viewControllers = []
    }
    
    private func truncatedToolbarText(_ text: String, font: UIFont, width: CGFloat) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        guard (text as NSString).size(withAttributes: attributes).width > width else { return text }
        // UIKit's overflow decision may inspect the configuration text before
        // applying the custom view's constraints. Bound that text as well, while
        // retaining the complete consumer string in the accessibility label.
        let characters = Array(text)
        var lower = 0, upper = characters.count
        while lower < upper {
            let middle = (lower + upper + 1) / 2
            let candidate = String(characters.prefix(middle)) + "…"
            if (candidate as NSString).size(withAttributes: attributes).width <= width { lower = middle }
            else { upper = middle - 1 }
        }
        return String(characters.prefix(lower)) + "…"
    }

    private func createToolbarItems(from items: JSArray, options: JSObject) throws -> [UIBarButtonItem] {
        var uiItems: [UIBarButtonItem] = []
        
        let imageBasePath = options["imageBasePath"] as? String
        
        for raw in items {
            guard let item = raw as? JSObject else {
                continue
            }
            
            let type = item["type"] as? Int ?? 0
            
            
            switch type {
            case 0:
                guard let data = item["data"] as? JSObject else {
                    throw SimpleError(message: "data is missing")
                }
                let tag = data["tag"] as? Int ?? 0
                let image = data["image"] as? String ?? ""
                let style = data["style"] as? Int ?? 0
                let tintColor = data["tintColor"] as? String ?? ""
                let tintColorDark = data["tintColorDark"] as? String
                let buttonItem = UIBarButtonItem(image: getImage(named: image, imageBasePath: imageBasePath)?.withRenderingMode(.alwaysTemplate), style: style != 0 ? .prominent : .plain, target: self, action: #selector(didTap))
                buttonItem.tag = tag
                buttonItem.identifier = data["identifier"] as? String
                buttonItem.isEnabled = data["enabled"] as? Bool ?? true
                buttonItem.accessibilityLabel = data["title"] as? String
                // UIKit uses the title when an icon item moves into overflow.
                // An accessibility label alone leaves that menu row without text.
                buttonItem.title = data["title"] as? String
                
                if(tintColor != "") {
                    buttonItem.tintColor = UIColor.dynamic(light: tintColor, dark: tintColorDark)
                }
                
                uiItems.append(buttonItem)
                continue
            case 1:
                let flexibleSpace = UIBarButtonItem.flexibleSpace()
                uiItems.append(flexibleSpace)
                continue
            case 2:
                guard let data = item["data"] as? JSObject else {
                    throw SimpleError(message: "data is missing")
                }
                guard let menuItems = data["items"] as? JSArray else {
                    throw SimpleError(message: "menu items are missing")
                }
                let image = data["image"] as? String ?? ""
                let title = data["title"] as? String ?? "test"
                let menuTitle = data["menuTitle"] as? String ?? ""
                let tintColor = data["tintColor"] as? String ?? ""
                let tintColorDark = data["tintColorDark"] as? String
                let actionButton = UIBarButtonItem(
                    title: title,
                    image: getImage(named: image, imageBasePath: imageBasePath)?.withRenderingMode(.alwaysTemplate),
                    primaryAction: nil,
                    menu: UIMenu(title: menuTitle, children: try getMenuItem(items: menuItems, imageBasePath: imageBasePath))
                )
                
                if let subtitle = data["subtitle"] as? String {
                    // The item supplies the Glass background; the button supplies
                    // accessible native text and menu interaction, with no second material.
                    var configuration = UIButton.Configuration.plain()
                    let maximumWidth = max(120, min(320, view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 120))
                    let titleFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: UIFont.systemFont(ofSize: 15, weight: .semibold))
                    let subtitleFont = UIFont.preferredFont(forTextStyle: .caption2)
                    let menuImage = getImage(named: image, imageBasePath: imageBasePath)?.withRenderingMode(.alwaysTemplate)
                    let textWidth = maximumWidth - 24 - (menuImage == nil ? 0 : menuImage!.size.width + 6)
                    configuration.title = truncatedToolbarText(title, font: titleFont, width: textWidth)
                    configuration.subtitle = truncatedToolbarText(subtitle, font: subtitleFont, width: textWidth)
                    configuration.titleAlignment = .leading
                    configuration.titleLineBreakMode = .byTruncatingTail
                    configuration.subtitleLineBreakMode = .byTruncatingTail
                    configuration.titlePadding = 1
                    configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
                    configuration.image = menuImage
                    configuration.imagePlacement = .trailing
                    configuration.imagePadding = 6
                    configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                        var attributes = attributes
                        attributes.font = titleFont
                        return attributes
                    }
                    let subtitleColor = data["subtitleTintColor"] as? String
                    configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                        var attributes = attributes
                        attributes.font = subtitleFont
                        if let subtitleColor { attributes.foregroundColor = UIColor(hex: subtitleColor) }
                        return attributes
                    }
                    let button = NativeToolbarMenuButton(configuration: configuration)
                    button.menu = actionButton.menu
                    button.showsMenuAsPrimaryAction = true
                    button.isEnabled = data["enabled"] as? Bool ?? true
                    button.accessibilityLabel = title
                    button.accessibilityValue = subtitle
                    button.accessibilityIdentifier = data["identifier"] as? String
                    button.titleLabel?.adjustsFontForContentSizeCategory = true
                    button.subtitleLabel?.adjustsFontForContentSizeCategory = true
                    if tintColor != "" { button.tintColor = UIColor.dynamic(light: tintColor, dark: tintColorDark) }
                    button.maximumContentWidth = maximumWidth
                    button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    button.sizeToFit()
                    button.widthAnchor.constraint(equalToConstant: button.intrinsicContentSize.width).isActive = true
                    actionButton.customView = button
                    // The custom view owns the text. Leaving the full title on
                    // the item makes UIKit measure that title again for overflow.
                    actionButton.title = nil
                    actionButton.image = nil
                    actionButton.sharesBackground = false
                }
                if #available(iOS 27.1, *) {
                    switch data["axisBehavior"] as? String {
                    case "horizontalOnly": actionButton.axisBehavior = .horizontalOnly
                    case "verticalPreferred": actionButton.axisBehavior = .verticalPreferred
                    default: actionButton.axisBehavior = .automatic
                    }
                }
                actionButton.identifier = data["identifier"] as? String
                actionButton.isEnabled = data["enabled"] as? Bool ?? true
                actionButton.accessibilityLabel = title
                if(tintColor != "") {
                    actionButton.tintColor = UIColor.dynamic(light: tintColor, dark: tintColorDark)
                }
                
                uiItems.append(actionButton)
                continue
            default:
                continue
            }
        }
        return uiItems
    }
    
    private func getMenuItem(items: JSArray, imageBasePath: String?) throws -> [UIMenuElement]  {
        var menuItems: [UIMenuElement] = []
        for rawMenuItem in items {
            guard let menuItem = rawMenuItem as? JSObject else {
                continue
            }
            let type = menuItem["type"] as? Int ?? 0
            
            switch type {
            case 0:
                guard let data = menuItem["data"] as? JSObject else {
                    throw SimpleError(message: "menuItem data is missing")
                }
                
                let identifier = data["identifier"] as? String ?? ""
                let title = data["title"] as? String ?? ""
                let image = data["image"] as? String ?? ""
                let attributes = data["attributes"] as? JSArray
                let tintColor = data["tintColor"] as? String ?? ""
                let tintColorDark = data["tintColorDark"] as? String
                
                let actionButton = UIAction(title: title, image: getImage(named: image, imageBasePath: imageBasePath)?.withRenderingMode(.alwaysTemplate), identifier: UIAction.Identifier(identifier), attributes: getMenuItemAttributes(attributes: attributes), handler: menuActionHandler )
                
                actionButton.state = data["checked"] as? Bool == true ? .on : .off
                if(tintColor != "") {
                    // An explicit web color must not be overridden by UIMenu's tint.
                    let color = UIColor.dynamic(light: tintColor, dark: tintColorDark).resolvedColor(with: traitCollection)
                    actionButton.image = actionButton.image?.withTintColor(color, renderingMode: .alwaysOriginal)
                }
                
                menuItems.append(actionButton)
                continue
            case 1:
                let divider = UIMenu(title: "", options: .displayInline, children: menuItems)
                menuItems = [divider]
                continue
            default:
                continue
            }
        }
        return menuItems
    }
    
    private func getMenuItemAttributes(attributes: JSArray?) -> UIMenuElement.Attributes {
        var menuItemAttributes: UIMenuElement.Attributes = []
        if let attributes = attributes, attributes.count != 0 {
            for rawAttribute in attributes {
                guard let attribute = rawAttribute as? Int else {
                    continue
                }
                switch attribute {
                case 1:
                    menuItemAttributes = menuItemAttributes.union(.destructive)
                    continue
                case 2:
                    menuItemAttributes = menuItemAttributes.union(.disabled)
                    continue
                case 3:
                    menuItemAttributes = menuItemAttributes.union(.hidden)
                    continue
                default:
                    menuItemAttributes = menuItemAttributes.union(.keepsMenuPresented)
                }
            }
        }
        
        return menuItemAttributes
    }
    
    func menuActionHandler(_ action: UIAction) -> Void {
        pluginDelegate?.notifyListeners("onToolbarMenuActionButtonDidTap", data: ["identifier": action.identifier.rawValue])
    }
    
    func toolbarItem(tag: Int) -> UIBarButtonItem? {
        (leadingPageItems + trailingPageItems + (topToolbar?.items ?? []) + (toolbar?.items ?? []))
            .first { $0.tag == tag && $0.isEnabled }
    }

    @objc func didTap(_ sender: UIBarButtonItem) {
        pluginDelegate?.notifyListeners("onToolbarButtonDidTap", data: ["tag": sender.tag])
    }
}

@available(iOS 26.0, *)
public class CapUIView {
    
    private var capUITabBarController: CapUITabBarController
    private weak var delegate: CapacitorUIKitPlugin?
    private var passthroughContainer: PassthroughView?
    
    init(delegate: CapacitorUIKitPlugin) {
        self.delegate = delegate
        self.capUITabBarController = CapUITabBarController()
        capUITabBarController.pluginDelegate = delegate
    }
    
    public func initialize() {
        self.render()
    }
    
    /// Use real containment so UIKit receives scene, trait and display changes.
    private func render() {
        guard let parent = delegate?.bridge?.viewController,
              let webView = delegate?.bridge?.webView else { return }
        if let container = self.passthroughContainer {
            webView.bringSubviewToFront(container)
            container.setNeedsLayout()
            return
        }
        let container = PassthroughView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tabController = self.capUITabBarController
        parent.addChild(self.capUITabBarController)
        webView.addSubview(container)
        let nativeView = self.capUITabBarController.view!
        nativeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nativeView)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            container.topAnchor.constraint(equalTo: webView.topAnchor),
            container.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
            nativeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nativeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            nativeView.topAnchor.constraint(equalTo: container.topAnchor),
            nativeView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        self.capUITabBarController.didMove(toParent: parent)
        self.passthroughContainer = container
        self.delegate?.notifyListeners("onUIViewReady", data: [:])
    }
    
    func reRender() {
        render()
    }

    func publishTabBarLayout() {
        capUITabBarController.view.layoutIfNeeded()
        capUITabBarController.publishTabBarLayout(force: true)
        capUITabBarController.publishTopToolbarLayout(force: true)
    }
    
    func createTabBar(_ items: [UITab], options: JSObject, searchBarItem: JSObject?) throws {
        render()
        try capUITabBarController.createTabs(items, options: options, searchBarItem: searchBarItem)
    }
    
    func removeTabs()  {
        capUITabBarController.removeTabs()
    }
    
    func createToolbar(_ items: JSArray, options: JSObject) throws {
        try capUITabBarController.createToolbar(items, options: options)
    }
    
  func afterTopToolbarTransition(_ operation: @escaping () -> Void) {
    capUITabBarController.afterTopToolbarTransition(operation)
  }
  func beginTopToolbarTransition(_ id: Int, source: JSObject, target: JSObject, backwards: Bool, duration: TimeInterval) throws -> TimeInterval {
    return try capUITabBarController.beginTopToolbarTransition(id, source: source, target: target, backwards: backwards, duration: duration)
  }
  func updateTopToolbarTransition(_ id: Int, progress: CGFloat) {
    capUITabBarController.updateTopToolbarTransition(id, progress: progress)
  }
  func finishTopToolbarTransition(_ id: Int, completed: Bool, resolved: @escaping () -> Void) {
    capUITabBarController.finishTopToolbarTransition(id, completed: completed, resolved: resolved)
  }

    func createTopToolbar(_ items: JSArray, options: JSObject) throws {
        try capUITabBarController.createTopToolbar(items, options: options)
    }
    
    func setToolbarItems(_ items: JSArray, options: JSObject) throws {
        try capUITabBarController.setToolItems(items, options: options)
    }
    
    func toolbarItem(tag: Int) -> UIBarButtonItem? {
        capUITabBarController.toolbarItem(tag: tag)
    }

    func topToolbarTopInset() -> CGFloat {
        capUITabBarController.view.layoutIfNeeded()
        return capUITabBarController.topToolbarTopInset()
    }

    func setTopToolbarItems(_ items: JSArray, options: JSObject) throws {
        try capUITabBarController.setTopToolItems(items, options: options)
    }
    
    func showTabBar() {
        capUITabBarController.showTabBar()
    }
    
    func hideTabBar() {
        capUITabBarController.hideTabBar()
    }
    
    func tabBarSelected() -> Int? {
        return capUITabBarController.tabBarSelected()
    }
    
    func showSearch() {
        capUITabBarController.showSearch()
    }
    
    func hideSearch() {
        capUITabBarController.hideSearch()
    }
    
    func showToolbar() {
        capUITabBarController.showToolbar()
    }
    
    func hideToolbar() {
        capUITabBarController.hideToolbar()
    }
    
    func showTopToolbar() {
        capUITabBarController.showTopToolbar()
    }
    
    func hideTopToolbar() {
        capUITabBarController.hideTopToolbar()
    }
    
    func destroy() {
        DispatchQueue.main.async {
            self.capUITabBarController.removeTabs()
            self.capUITabBarController.willMove(toParent: nil)
            self.capUITabBarController.view.removeFromSuperview()
            self.capUITabBarController.removeFromParent()
            self.passthroughContainer?.removeFromSuperview()
            self.passthroughContainer = nil
            self.capUITabBarController.pluginDelegate = nil
            self.delegate = nil
        }
    }
}

/// Hex string -> UIColor converter
extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        if hexSanitized.count == 6 {
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: alpha)
        } else if hexSanitized.count == 8 {
            let r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgb & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        } else {
            self.init(white: 1.0, alpha: alpha) // fallback to white
        }
    }
    
    static func dynamic(light: String, dark: String?) -> UIColor {
        let lightColor = UIColor(hex: light)
        let darkColor = dark.flatMap { UIColor(hex: $0) } ?? lightColor
        return UIColor { trait in
            trait.userInterfaceStyle == .dark ? darkColor : lightColor
        }
    }
}

/// Bound the size UIKit uses to place a text menu item. A constraint alone does
/// not change UIButton's intrinsic width, so long labels could be moved to overflow.
@available(iOS 26.0, *)
private final class NativeToolbarMenuButton: UIButton {
    var maximumContentWidth: CGFloat = 320 {
        didSet { invalidateIntrinsicContentSize() }
    }
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = min(size.width, maximumContentWidth)
        return size
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var result = super.sizeThatFits(size)
        result.width = min(result.width, maximumContentWidth)
        return result
    }
}
