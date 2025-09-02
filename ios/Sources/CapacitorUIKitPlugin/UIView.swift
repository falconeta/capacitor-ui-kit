//
//  UIView.swift
//  Pods
//
//

import Foundation
import Capacitor
import UIKit

class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        
        if hitView == self {
            return nil
        }
        return hitView
    }
}

class CapUIViewController: UIViewController, UITabBarDelegate {
    
    var tabBarEl: UITabBar?
    var pluginDelegate: CapacitorUIKitPlugin?
    
    override func loadView() {
        let passthroughView = PassthroughView(frame: UIScreen.main.bounds)
        passthroughView.backgroundColor = .clear // importante per non coprire lo sfondo
        view = passthroughView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    func createTabBar(_ items: [UITabBarItem], options: JSObject) throws {
        tabBarEl?.removeFromSuperview()
        tabBarEl?.delegate = nil
        tabBarEl = nil
        
        tabBarEl = UITabBar()
        tabBarEl!.translatesAutoresizingMaskIntoConstraints = false
        tabBarEl!.isTranslucent = false
        tabBarEl!.delegate = self
        tabBarEl!.items = items
        
        guard let selectedTag = options["selectedTag"] as? Int else {
            throw SimpleError(message: "selectedTag is missing")
        }
        
        tabBarEl!.selectedItem = items.first(where: { ($0.tag) == selectedTag }) ?? items[0]
        
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
        
        tabBarEl!.tintColor = UIColor(hex: tintColor)
        tabBarEl!.unselectedItemTintColor = UIColor(hex: unselectedItemTintColor)
        
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: CGFloat(unselectedFontSize)),
            .foregroundColor: UIColor(hex: unselectedFontColor)
        ]
        
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: UIFont.boldSystemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: UIColor(hex: fontColor)
        ]
        
        tabBarEl!.standardAppearance = appearance
        
        view.addSubview(tabBarEl!)
        
        NSLayoutConstraint.activate([
            tabBarEl!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarEl!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarEl!.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
    }
    
    func showTabBar() {
        tabBarEl?.isHidden = false
    }
    
    func hideTabBar() {
        tabBarEl?.isHidden = true
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        pluginDelegate?.notifyListeners("onTabBarDidSelect", data: ["tag": item.tag])
    }
    
    func destroy(){
        
    }
}

public class CapUIView {
    
    
    private var capUIViewController: CapUIViewController
    
    private var delegate: CapacitorUIKitPlugin?
    
    init(delegate: CapacitorUIKitPlugin) {
        self.delegate = delegate
        self.capUIViewController = CapUIViewController()
        capUIViewController.pluginDelegate = delegate
        self.render()
    }
    
    private func render() {
        DispatchQueue.main.async {
            guard let webView = self.delegate?.bridge?.webView else {
                return
            }
            
            webView.superview?.insertSubview(self.capUIViewController.view, aboveSubview: webView)
            
            self.delegate?.notifyListeners("onUIViewReady", data: [:])
        }
    }
    
    func createTabBar(_ items: [UITabBarItem], options: JSObject) throws {
        try capUIViewController.createTabBar(items, options: options)
    }
    
    func showTabBar() {
        capUIViewController.showTabBar()
    }
    
    func hideTabBar() {
        capUIViewController.hideTabBar()
    }
    
    func destroy() {
        DispatchQueue.main.async {
            self.capUIViewController.destroy()
            self.delegate = nil
            self.capUIViewController.view = nil
        }
    }
    
}

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
            self.init(white: 1.0, alpha: alpha) // fallback bianco
        }
    }
}
