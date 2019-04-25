//
//  HomeViewController.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/23/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit
import MapKit

class HomeViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var requestRideBtn: RoundedShadowButton!

    var delegate: CenterVCDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
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

