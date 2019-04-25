//
//  SlidePanelViewController.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/25/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit

class SlidePanelViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func signUpLoginBtnWasPressed(_ sender: Any) {
        let sb = UIStoryboard(name: "Main", bundle: Bundle.main)
        guard let loginVC = sb.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController else { return }
        present(loginVC, animated: true, completion: nil)
    }

}
