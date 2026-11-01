import UIKit
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
      
      let normalImage = getImage(named: image, imageBasePath: imageBasePath)?.withRenderingMode(.alwaysTemplate)
      let selectedImage = getImage(named: imageSelected, imageBasePath: imageBasePath)?.withRenderingMode(.alwaysTemplate) ?? normalImage
      let tab = UITab(title: title, image: normalImage, identifier: String(tag)) { tab in
        let content = UIViewController()
        content.view.backgroundColor = .clear
        let navigation = UINavigationController(rootViewController: content)
        navigation.view.backgroundColor = .clear
        navigation.setNavigationBarHidden(true, animated: false)
        return navigation
      }
      
      if #available(iOS 26.1, *) {
        tab.selectedImage = selectedImage
      } else {
        tab.viewController?.tabBarItem.selectedImage = selectedImage
      }
      
      uiItems.append(tab)
      
    }
    try capUIView?.createTabBar(uiItems, options: options, searchBarItem: searchBarItem)
  }
  
  func publishTabBarLayout() {
    capUIView?.publishTabBarLayout()
  }

  public func removeTabs() {
    capUIView?.removeTabs()
  }
  
  public func initialize() {
    capUIView?.initialize()
  }
  public func reRender() {
    capUIView?.reRender()
  }
  
  public func createToolbar(_ items: JSArray, options: JSObject) throws {
    try capUIView?.createToolbar(items, options: options)
  }
  
  func afterTopToolbarTransition(_ operation: @escaping () -> Void) {
    guard let capUIView else { operation(); return }
    capUIView.afterTopToolbarTransition(operation)
  }
  public func beginTopToolbarTransition(_ id: Int, source: JSObject, target: JSObject, backwards: Bool, duration: TimeInterval) throws -> TimeInterval {
    return try capUIView?.beginTopToolbarTransition(id, source: source, target: target, backwards: backwards, duration: duration) ?? duration
  }
  public func updateTopToolbarTransition(_ id: Int, progress: CGFloat) {
    capUIView?.updateTopToolbarTransition(id, progress: progress)
  }
  public func finishTopToolbarTransition(_ id: Int, completed: Bool, resolved: @escaping () -> Void) {
    guard let capUIView else { resolved(); return }
    capUIView.finishTopToolbarTransition(id, completed: completed, resolved: resolved)
  }

  public func createTopToolbar(_ items: JSArray, options: JSObject) throws {
    try capUIView?.createTopToolbar(items, options: options)
  }
  
  public func setToolbarItems(_ items: JSArray, options: JSObject) throws {
    try capUIView?.setToolbarItems(items, options: options)
  }
  
  func toolbarItem(tag: Int) -> UIBarButtonItem? {
    capUIView?.toolbarItem(tag: tag)
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
