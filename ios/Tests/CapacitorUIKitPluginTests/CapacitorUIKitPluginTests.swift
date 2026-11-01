import XCTest
import UIKit
@testable import CapacitorUIKitPlugin

@available(iOS 26.0, *)
@MainActor
final class CapacitorUIKitTests: XCTestCase {
    func testBottomInsetDoesNotCountSystemSafeAreaTwice() {
        let insets = TabBarContentInsets(bounds: CGRect(x: 0, y: 0, width: 390, height: 844),
                                        content: CGRect(x: 0, y: 59, width: 390, height: 702),
                                        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0), visible: true)
        XCTAssertEqual(insets.bottom, 49)
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.left, 0)
        XCTAssertEqual(insets.right, 0)
    }

    func testDuoRailCanAlreadyBeInsideTheSystemSafeArea() {
        let insets = TabBarContentInsets(bounds: CGRect(x: 0, y: 0, width: 466, height: 678),
                                        content: CGRect(x: 0, y: 0, width: 382, height: 644),
                                        safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84), visible: true)
        XCTAssertEqual(insets, TabBarContentInsets())
    }

    func testSidebarReservesOnlyItsAdditionalWidth() {
        let insets = TabBarContentInsets(bounds: CGRect(x: 0, y: 0, width: 900, height: 700),
                                        content: CGRect(x: 320, y: 0, width: 496, height: 666),
                                        safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84), visible: true)
        XCTAssertEqual(insets.left, 320)
        XCTAssertEqual(insets.right, 0)
        XCTAssertEqual(insets.bottom, 0)
    }

    func testHiddenBarsNeverLeaveContentInsets() {
        let insets = TabBarContentInsets(bounds: CGRect(x: 0, y: 0, width: 900, height: 700),
                                        content: CGRect(x: 320, y: 0, width: 496, height: 666),
                                        safeArea: .zero, visible: false)
        XCTAssertEqual(insets, TabBarContentInsets())
    }

    func testContentTouchesPassThrough() {
        let overlay = PassthroughView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let content = UIView(frame: overlay.bounds)
        overlay.addSubview(content)
        XCTAssertNil(overlay.hitTest(CGPoint(x: 100, y: 100), with: nil))
    }

    func testHiddenAncestorDoesNotCaptureTouches() {
        let overlay = PassthroughView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let hiddenContainer = UIView(frame: overlay.bounds)
        hiddenContainer.isHidden = true
        hiddenContainer.addSubview(UITabBar(frame: overlay.bounds))
        overlay.addSubview(hiddenContainer)
        XCTAssertNil(overlay.hitTest(CGPoint(x: 100, y: 100), with: nil))
    }
    func testToolbarBackgroundDoesNotCaptureWebHeaderTouches() {
        let overlay = PassthroughView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 390, height: 44))
        overlay.addSubview(toolbar)
        XCTAssertNil(overlay.hitTest(CGPoint(x: 120, y: 22), with: nil))
    }

    func testToolbarButtonsStillReceiveTouches() {
        let overlay = PassthroughView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 390, height: 44))
        let button = UIButton(frame: CGRect(x: 8, y: 0, width: 44, height: 44))
        overlay.addSubview(toolbar)
        toolbar.addSubview(button)
        XCTAssertNotNil(overlay.hitTest(CGPoint(x: 30, y: 22), with: nil))
    }

}
