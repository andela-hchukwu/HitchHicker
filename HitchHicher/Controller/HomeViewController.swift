//
//  HomeViewController.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/23/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit
import MapKit
import RevealingSplashView

class HomeViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var requestRideBtn: RoundedShadowButton!

    var delegate: CenterVCDelegate?

    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self

        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()

        revealingSplashView.heartAttack = true
    }

    @IBAction func requestRideBtnWasPressed(_ sender: Any) {
        requestRideBtn.animateButton(shouldLoad: true, withMessage: nil)
    }
    @IBAction func menuBtnWasPressed(_ sender: Any) {
        delegate?.toggleLeftPanel()
    }

}

extension HomeViewController: MKMapViewDelegate {

}

