//
//  ContainerViewController.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/25/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit
import QuartzCore

enum SlideOutState {
    case collapsed
    case leftPanelExpanded
}

enum ShowWhichViewController {
    case homeViewController
}

var showVC: ShowWhichViewController = .homeViewController

class ContainerViewController: UIViewController {

    var homeVC: HomeViewController!
    var leftVC: SlidePanelViewController!
    var centerController: UIViewController!
    var currentState: SlideOutState = .collapsed {
        didSet {
            let shouldShowShadow = (currentState != .collapsed)
            shouldShowShadowForCenterViewController(shouldShowShadow)
        }
    }

    var isHidden = false
    let centerPanelExpandedOffset: CGFloat = 160

    var tap: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        initCenter(screen: showVC)
    }

    func initCenter(screen: ShowWhichViewController) {
        var presentingController: UIViewController

        showVC = screen

        if homeVC == nil {
            homeVC = UIStoryboard.homeViewController()
            homeVC.delegate = self
        }

        presentingController = homeVC

        if let controller = centerController {
            controller.view.removeFromSuperview()
            controller.removeFromParent()
        }

        centerController = presentingController

        view.addSubview(centerController.view)
        addChild(centerController)
        centerController.didMove(toParent: self)
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }

    override var prefersStatusBarHidden: Bool {
        return isHidden
    }
}

extension ContainerViewController: CenterVCDelegate {

    func toggleLeftPanel() {
        let notAlreadyExpanded = (currentState != .leftPanelExpanded)

        if notAlreadyExpanded {
            addLeftPanelViewController()
        }
        animateLeftPanel(shouldExpand: notAlreadyExpanded)
    }

    func addLeftPanelViewController() {
        if leftVC == nil {
            leftVC = UIStoryboard.leftViewController()
            addChildSidePanelViewController(leftVC)
        }
    }

    func addChildSidePanelViewController(_ sidePanelController: SlidePanelViewController) {
        view.insertSubview(sidePanelController.view, at: 0)
        addChild(sidePanelController)
        sidePanelController.didMove(toParent: self)
    }

    @objc func animateLeftPanel(shouldExpand: Bool) {
        isHidden = !isHidden
        animateStatusBar()

        if shouldExpand {
            setupWhiteCoverView()

            currentState = .leftPanelExpanded

            animateCenterPanelXPosition(targetPosition: centerController.view.frame.width - centerPanelExpandedOffset)
        } else {

            hideWhiteCoverView()
            animateCenterPanelXPosition(targetPosition: 0) { (finished) in
                if finished {
                    self.currentState = .collapsed
                    self.leftVC = nil
                }
            }
        }
    }

    func animateCenterPanelXPosition(targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.centerController.view.frame.origin.x = targetPosition
        }, completion: completion)
    }

    func setupWhiteCoverView() {
        let whiteCoverView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        whiteCoverView.alpha = 0.0
        whiteCoverView.backgroundColor = UIColor.white
        whiteCoverView.tag = 25

        self.centerController.view.addSubview(whiteCoverView)
        whiteCoverView.fadeTo(alphaValue: 0.75, withDuration: 0.2)

        tap = UITapGestureRecognizer(target: self, action: #selector(animateLeftPanel(shouldExpand:)))
        tap.numberOfTapsRequired = 1

        self.centerController.view.addGestureRecognizer(tap)
    }

    func hideWhiteCoverView() {
        centerController.view.removeGestureRecognizer(tap)
        for subview in self.centerController.view.subviews {
            if subview.tag == 25 {
                UIView.animate(withDuration: 0.2, animations: {
                    subview.alpha = 0.0
                }) { (finished) in
                    subview.removeFromSuperview()
                }
            }
        }
    }

    func shouldShowShadowForCenterViewController(_ status: Bool) {
        if status {
            centerController.view.layer.shadowOpacity = 0.6
        } else {
            centerController.view.layer.shadowOpacity = 0.0
        }
    }

    func animateStatusBar() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
    }

}

private extension UIStoryboard {

    class func mainStoryboard() -> UIStoryboard {
        return UIStoryboard(name: "Main", bundle: Bundle.main)
    }

    class func leftViewController() -> SlidePanelViewController? {
        return mainStoryboard().instantiateViewController(withIdentifier: "SlidePanelViewController") as? SlidePanelViewController
    }

    class func homeViewController() -> HomeViewController? {
        return mainStoryboard().instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController
    }
}
