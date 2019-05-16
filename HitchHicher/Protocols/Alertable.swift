//
//  Alertable.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 5/16/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit

protocol Alertable {}

extension Alertable where Self: UIViewController {

    func showAlert(_ msg: String) {
        let alertController = UIAlertController(title: "Error:", message: msg, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(action)
        present(alertController, animated: true, completion: nil)
    }
}
