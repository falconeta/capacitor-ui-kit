import Foundation
import Capacitor

struct SimpleError: Error {
    let message: String
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
        CAPPluginMethod(name: "createTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "createToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setToolbarItems", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = CapacitorUIKit()
    
    
    override public func load() {
        implementation.createView(delegate: self)
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
                
                try implementation.createTabBar(items, options: options, searchBarItem: searchBarItem)
                call.resolve([:])
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
}
