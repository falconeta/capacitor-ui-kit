import Foundation
import Capacitor

@available(iOS 26.0, *)
@objc public class CapacitorUIKit: NSObject {
    
    private var capUIView: CapUIView?
    
    func createView(delegate: CapacitorUIKitPlugin) {
        capUIView = CapUIView(delegate: delegate)
    }
    
    public func createTabBar(_ items: JSArray, options: JSObject, searchBarItem: JSObject?) throws {
        var uiItems: [UITab] = []
        
        let imageBasePath = options["imageBasePath"] as? String
        
        for raw in items {
            guard let item = raw as? JSObject else {
                continue
            }
            
            let title = item["title"] as? String ?? "Untitled"
            let tag = item["tag"] as? Int ?? 0
            let image = item["image"] as? String ?? ""
            let imageSelected = item["imageSelected"] as? String ?? ""
            
            let tab = UITab(title: title, image: getImage(named: image, imageBasePath: imageBasePath), identifier: String(tag)) { tab in
                UINavigationController(
                    rootViewController: UIViewController()
                )
            }
            
            tab.viewController?.tabBarItem.selectedImage = getImage(named: imageSelected, imageBasePath: imageBasePath)
            
            uiItems.append(tab)
            
        }
        try capUIView?.createTabBar(uiItems, options: options, searchBarItem: searchBarItem)
    }
    
    public func removeTabs() {
        capUIView?.removeTabs()
    }
    
    public func reRender() {
        capUIView?.reRender()
    }
    
    public func createToolbar(_ items: JSArray, options: JSObject) throws {
        try capUIView?.createToolbar(items, options: options)
    }
    
    public func createTopToolbar(_ items: JSArray, options: JSObject) throws {
        try capUIView?.createTopToolbar(items, options: options)
    }
    
    public func setToolbarItems(_ items: JSArray, options: JSObject) throws {
        try capUIView?.setToolbarItems(items, options: options)
    }
    
    public func setTopToolbarItems(_ items: JSArray, options: JSObject) throws {
        try capUIView?.setTopToolbarItems(items, options: options)
    }
    
    public func showTabBar() {
        capUIView?.showTabBar()
    }
    
    public func hideTabBar() {
        capUIView?.hideTabBar()
    }
    
    public func tabBarSelected() -> Int? {
        return capUIView?.tabBarSelected()
    }
    
    public func showSearch() {
        capUIView?.showSearch()
    }
    
    public func hideSearch() {
        capUIView?.hideSearch()
    }
    
    public func showToolbar() {
        capUIView?.showToolbar()
    }
    
    public func hideToolbar() {
        capUIView?.hideToolbar()
    }
    
    public func showTopToolbar() {
        capUIView?.showTopToolbar()
    }
    
    public func hideTopToolbar() {
        capUIView?.hideTopToolbar()
    }
}
