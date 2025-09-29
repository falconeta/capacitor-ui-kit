import Foundation
import Capacitor
import UIKit

/// A passthrough container view that only intercepts touches for the UITabBar.
/// All other touches are passed through to the underlying webView.
final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        if let hit = passThroughFirstHit(UITabBar.self, point, event) { return hit }
        if let hit = passThroughFirstHit(UISearchBar.self, point, event) { return hit }

        if #available(iOS 13.0, *),
           let hit = passThroughFirstHit(UISearchTextField.self, point, event) { return hit }

        if let hit = passThroughFirstHit(UITableView.self, point, event) { return hit }
        if let hit = passThroughFirstHit(UIToolbar.self, point, event) { return hit }

        return nil
    }

    private func passThroughFirstHit<T: UIView>(_ type: T.Type, _ point: CGPoint, _ event: UIEvent?) -> UIView? {
        for v in findSubviews(ofType: type) where v.isUserInteractionEnabled && !v.isHidden && v.alpha > 0.01 {
            let p = v.convert(point, from: self)
            if let hit = v.hitTest(p, with: event) { return hit }
        }
        return nil
    }
    
    private func findSubviews<T: UIView>(ofType type: T.Type) -> [T] {
            var result: [T] = []
            func dfs(_ view: UIView) {
                if let v = view as? T { result.append(v) }
                // reversed: le ultime aggiunte sono davanti
                for sub in view.subviews.reversed() { dfs(sub) }
            }
            dfs(self)
            return result
        }
}

@available(iOS 26, *)
class CapUITabBarController: UITabBarController, UITabBarControllerDelegate {
    
    var pluginDelegate: CapacitorUIKitPlugin?
    var search: UISearchTab?
    private var toolbar: UIToolbar?
    private var topToolbar: UIToolbar?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.backgroundColor = .clear
        
        // Remove default background and shadow, make translucent
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.isTranslucent = true
    }
    
    /// Create and configure tabs based on incoming items + options
    func createTabs(_ items: [UITab], options: JSObject, searchBarItem: JSObject?) throws {
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
            
            return nav
        }
        
        // Assign incoming tabs
        self.tabs = items
        
        // Append search tab by default
        if let search = search {
            self.tabs.append(search)
            search.automaticallyActivatesSearch = true
        }
        
        // Extract options
        guard let selectedTag = options["selectedTag"] as? Int else {
            throw SimpleError(message: "selectedTag is missing")
        }
        guard let fontSize = options["fontSize"] as? Float else {
            throw SimpleError(message: "fontSize is missing")
        }
        guard let fontColor = options["fontColor"] as? String else {
            throw SimpleError(message: "fontColor is missing")
        }
        guard let tintColor = options["tintColor"] as? String else {
            throw SimpleError(message: "tintColor is missing")
        }
        guard let unselectedFontSize = options["unselectedFontSize"] as? Float else {
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
        
        // Select initial tab based on tag
        if let targetTab = tabs.first(where: { Int($0.identifier) == selectedTag }) {
            self.selectedTab = targetTab
        }
        
        // Configure tab bar appearance
        tabBar.tintColor = UIColor.dynamic(light: tintColor, dark: tintColorDark)
        tabBar.unselectedItemTintColor = UIColor.dynamic(light: unselectedItemTintColor, dark: unselectedItemTintColorDark)
        
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: CGFloat(unselectedFontSize)),
            .foregroundColor: UIColor.dynamic(light: unselectedFontColor, dark: unselectedFontColorDark)
        ]
        
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: UIFont.boldSystemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: UIColor.dynamic(light: fontColor, dark: fontColorDark)
        ]
        
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
    
    func tabBarController(_ tabBarController: UITabBarController,
                          didSelectTab selectedTab: UITab,
                          previousTab: UITab?) {
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
            tb.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 16), // align right with tabBar
            tb.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor, constant: -16), // align right with tabBar
            tb.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -16) // 16pt padding
        ])
    }
    
    func createTopToolbar(_ items: JSArray, options: JSObject) throws {
        
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
        
        NSLayoutConstraint.activate([
            tb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), // align right with tabBar
            tb.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16), // align right with tabBar
            tb.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        ])
    }
    
    func setToolItems(_ items: JSArray, options: JSObject) throws {
        try toolbar?.setItems(createToolbarItems(from: items, options: options), animated: true)
    }
    
    func setTopToolItems(_ items: JSArray, options: JSObject) throws {
        try topToolbar?.setItems(createToolbarItems(from: items, options: options), animated: true)
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
        topToolbar?.isHidden = false
    }
    
    /// Hide the search tab dynamically
    func hideSearch() {
        self.tabs.removeAll { $0 is UISearchTab }
    }
    
    func hideToolbar() {
        toolbar?.isHidden = true
    }
    
    func hideTopToolbar() {
        topToolbar?.isHidden = true
    }
    
    /// Show tab bar
    func showTabBar() {
        tabBar.isHidden = false
    }
    
    /// Hide tab bar
    func hideTabBar() {
        tabBar.isHidden = true
    }
    
    /// Destroy tab bar and clear controllers
    func destroy() {
        self.viewControllers = []
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
                let buttonItem = UIBarButtonItem(image: getImage(named: image, imageBasePath: imageBasePath), style: style != 0 ? .prominent : .plain, target: self, action: #selector(didTap))
                buttonItem.tag = tag
                
                if(tintColor != "") {
                    buttonItem.tintColor = UIColor.dynamic(light: tintColor, dark: nil)
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
                let actionButton = UIBarButtonItem(
                    title: title,
                    image: getImage(named: image, imageBasePath: imageBasePath),
                    primaryAction: nil,
                    menu: UIMenu(title: menuTitle, children: try getMenuItem(items: menuItems, imageBasePath: imageBasePath))
                )
                
                if(tintColor != "") {
                    actionButton.tintColor = UIColor.dynamic(light: tintColor, dark: nil)
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
                
                menuItems.append(UIAction(title: title, image: getImage(named: image, imageBasePath: imageBasePath), identifier: UIAction.Identifier(identifier), attributes: getMenuItemAttributes(attributes: attributes), handler: menuActionHandler ))
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
    
    @objc func didTap(_ sender: UIBarButtonItem) {
        pluginDelegate?.notifyListeners("onToolbarButtonDidTap", data: ["tag": sender.tag])
    }
}

@available(iOS 26.0, *)
public class CapUIView {
    
    private var capUITabBarController: CapUITabBarController
    private var delegate: CapacitorUIKitPlugin?
    
    init(delegate: CapacitorUIKitPlugin) {
        self.delegate = delegate
        self.capUITabBarController = CapUITabBarController()
        capUITabBarController.pluginDelegate = delegate
        self.render()
    }
    
    /// Attach UITabBarController on top of the webView
    private func render() {
        DispatchQueue.main.async {
            guard let webView = self.delegate?.bridge?.webView else { return }
            
            // Passthrough container placed above the webView
            let passthroughContainer = PassthroughView(frame: webView.superview?.bounds ?? .zero)
            passthroughContainer.backgroundColor = .clear
            
            webView.superview?.insertSubview(passthroughContainer, aboveSubview: webView)
            
            // Add UITabBarController.view inside passthrough
            passthroughContainer.addSubview(self.capUITabBarController.view)
            self.capUITabBarController.view.frame = passthroughContainer.bounds
            self.capUITabBarController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            self.delegate?.notifyListeners("onUIViewReady", data: [:])
        }
    }
    
    func createTabBar(_ items: [UITab], options: JSObject, searchBarItem: JSObject?) throws {
        try capUITabBarController.createTabs(items, options: options, searchBarItem: searchBarItem)
    }
    
    func createToolbar(_ items: JSArray, options: JSObject) throws {
        try capUITabBarController.createToolbar(items, options: options)
    }
    
    func createTopToolbar(_ items: JSArray, options: JSObject) throws {
        try capUITabBarController.createTopToolbar(items, options: options)
    }
    
    func setToolbarItems(_ items: JSArray, options: JSObject) throws {
        try capUITabBarController.setToolItems(items, options: options)
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
            self.capUITabBarController.destroy()
            self.delegate = nil
            self.capUITabBarController.view = nil
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
