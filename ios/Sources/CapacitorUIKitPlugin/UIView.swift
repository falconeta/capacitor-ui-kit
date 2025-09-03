import Foundation
import Capacitor
import UIKit

/// A passthrough container view that only intercepts touches for the UITabBar.
/// All other touches are passed through to the underlying webView.
class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 1) UITabBar
        if let tabBar: UITabBar = findSubview(ofType: UITabBar.self, in: self) {
            let p = tabBar.convert(point, from: self)
            if let hit = tabBar.hitTest(p, with: event) {
                return hit
            }
        }
        
        // 2) UISearchBar
        if let searchBar: UISearchBar = findSubview(ofType: UISearchBar.self, in: self) {
            let p = searchBar.convert(point, from: self)
            if let hit = searchBar.hitTest(p, with: event) {
                return hit
            }
        }
        
        // 3) UISearchTextField (iOS 13+)
        if #available(iOS 13.0, *),
           let searchField: UISearchTextField = findSubview(ofType: UISearchTextField.self, in: self) {
            let p = searchField.convert(point, from: self)
            if let hit = searchField.hitTest(p, with: event) {
                return hit
            }
        }
        
        // 4) Vista del SearchResultsViewController (tabella e celle)
        if let resultsView: UITableView = findSubview(ofType: UITableView.self, in: self) {
            let p = resultsView.convert(point, from: self)
            if let hit = resultsView.hitTest(p, with: event) {
                return hit
            }
        }
        
        // Tutto il resto → passa al webView
        return nil
    }
    
    /// Ricerca ricorsiva per sottoview di un tipo specifico
    private func findSubview<T: UIView>(ofType type: T.Type, in root: UIView) -> T? {
        if let v = root as? T { return v }
        for sub in root.subviews {
            if let found: T = findSubview(ofType: type, in: sub) {
                return found
            }
        }
        return nil
    }
}

@available(iOS 18.4, *)
class CapUITabBarController: UITabBarController, UITabBarControllerDelegate {
    
    var pluginDelegate: CapacitorUIKitPlugin?
    var search: UISearchTab?
    
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
    
    /// Called when a tab is selected (UITab API, iOS 18+)
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
    
    /// Show the search tab dynamically
    func showSearch() {
        if let search = search, !self.tabs.contains(where: { $0 is UISearchTab }) {
            self.tabs.append(search)
        }
    }
    
    /// Hide the search tab dynamically
    func hideSearch() {
        self.tabs.removeAll { $0 is UISearchTab }
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
}

@available(iOS 18.4, *)
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
