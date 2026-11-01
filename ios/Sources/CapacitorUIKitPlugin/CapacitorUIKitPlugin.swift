import Foundation
import Capacitor

struct SimpleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
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
        CAPPluginMethod(name: "beginTopToolbarTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateTopToolbarTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "finishTopToolbarTransition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "initialize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reRender", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "createTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeTabs", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "tabBarSelected", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideSearch", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "createToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setToolbarItems", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showTopToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideTopToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "createTopToolbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setTopToolbarItems", returnType: CAPPluginReturnPromise)
        
    ]
    private let implementation = CapacitorUIKit()
    
    
    override public func load() {
        implementation.createView(delegate: self)
    }
    
    override public func addListener(_ call: CAPPluginCall) {
        super.addListener(call)
        if ["onTabBarLayoutChange", "onTopToolbarLayoutChange"].contains(call.getString("eventName") ?? "") {
            // A listener may arrive after layout, or while UIKit is creating the tabs.
            DispatchQueue.main.async { [weak self] in
                self?.implementation.publishTabBarLayout()
            }
        }
    }

    @objc func beginTopToolbarTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            do {
                guard let id = call.getInt("id"), let source = call.getObject("from"), let target = call.getObject("to") else {
                    throw SimpleError(message: "Toolbar transition requires id, from and to")
                }
                let nativeDuration = try self.implementation.beginTopToolbarTransition(id, source: source, target: target,
                    backwards: call.getString("direction") == "back", duration: (call.getDouble("duration") ?? 540) / 1000)
                // UIKit owns its standard spring/morph. Let the web page use
                // the same duration without pausing native material rendering.
                DispatchQueue.main.async { call.resolve(["duration": nativeDuration * 1000, "timing": "native"]) }
            } catch { call.reject(error.localizedDescription) }
        }
    }

    @objc func updateTopToolbarTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.implementation.updateTopToolbarTransition(call.getInt("id") ?? -1, progress: CGFloat(call.getDouble("progress") ?? 0))
            call.resolve()
        }
    }

    @objc func finishTopToolbarTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.implementation.finishTopToolbarTransition(call.getInt("id") ?? -1, completed: call.getBool("completed") ?? false) { call.resolve() }
        }
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
                
                implementation.afterTopToolbarTransition { [self] in
                    do {
                        try implementation.createTabBar(items, options: options, searchBarItem: searchBarItem)
                        call.resolve([:])
                    } catch { call.reject(error.localizedDescription) }
                }
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
    
    @objc func removeTabs(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.removeTabs()
            call.resolve([:])
            
        }
    }
    
    @objc func initialize(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.initialize()
            call.resolve([:])
            
        }
    }
    
    
    @objc func reRender(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.reRender()
            call.resolve([:])
            
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
    
    @objc func createTopToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            do {
                guard let items = call.getArray("items", JSObject.self) else {
                    throw SimpleError(message: "items is missing")
                }
                
                guard let options = call.getObject("options") else {
                    throw SimpleError(message: "options is missing")
                }
                
                try implementation.createTopToolbar(items, options: options)
                call.resolve([:])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
    
    @objc func setTopToolbarItems(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            do {
                guard let items = call.getArray("items", JSObject.self) else {
                    throw SimpleError(message: "items is missing")
                }
                
                guard let options = call.getObject("options") else {
                    throw SimpleError(message: "options is missing")
                }
                
                try implementation.setTopToolbarItems(items, options: options)
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
    
    @objc func tabBarSelected(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            call.resolve(["value": implementation.tabBarSelected() ?? nil ])
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
    
    @objc func showTopToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.showTopToolbar()
            call.resolve([:])
        }
    }
    
    @objc func hideTopToolbar(_ call: CAPPluginCall) {
        DispatchQueue.main.sync {
            implementation.hideTopToolbar()
            call.resolve([:])
        }
    }
}
