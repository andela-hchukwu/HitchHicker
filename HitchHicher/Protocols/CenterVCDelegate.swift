//
//  CenterVCDelegate.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/25/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import Foundation

protocol CenterVCDelegate {
    func toggleLeftPanel()
    func addLeftPanelViewController()
    func animateLeftPanel(shouldExpand: Bool)
}
