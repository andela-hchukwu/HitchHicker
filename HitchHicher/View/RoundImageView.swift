//
//  RoundImageView.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/25/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit

class RoundImageView: UIImageView {

    override func awakeFromNib() {
        setupView()
    }

    func setupView() {
        self.layer.cornerRadius = self.frame.width / 2
        self.clipsToBounds = true
    }

}
