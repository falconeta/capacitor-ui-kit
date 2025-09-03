import Foundation
import Capacitor
import SVGKit

@available(iOS 18.4, *)
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
    
    public func showTabBar() {
        capUIView?.showTabBar()
    }
    
    public func hideTabBar() {
        capUIView?.hideTabBar()
    }
    
    public func showSearch() {
        capUIView?.showSearch()
    }
    
    public func hideSearch() {
        capUIView?.hideSearch()
    }
    
    private func getImage(named iconName: String, imageBasePath: String?) -> UIImage? {
        guard let url = Bundle.main.url(forResource: "public/\(imageBasePath ?? "assets")/\(iconName)", withExtension: "svg") else {
            print("⚠️ SVG not found:", iconName)
            return nil
        }
        
        guard let svgImage = SVGKImage(contentsOf: url) else {
            print("⚠️ Error on create SVGKImage from local URL")
            return nil
        }
        
        return svgImage.uiImage
    }
}
