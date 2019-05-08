//
//  SlidePanelViewController.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/25/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit
import Firebase

class SlidePanelViewController: UIViewController {

    @IBOutlet weak var userEmailLbl: UILabel!
    @IBOutlet weak var userAccountTypeLbl: UILabel!
    @IBOutlet weak var loginOutBtn: UIButton!
    @IBOutlet weak var pickupModeSwitch: UISwitch!
    @IBOutlet weak var pickupModeLbl: UILabel!
    @IBOutlet weak var userProfileImage: RoundImageView!

    let currentUserId = Auth.auth().currentUser?.uid
    let appDelegate = AppDelegate.getAppDelegate()

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        pickupModeSwitch.isOn = false
        pickupModeSwitch.isHidden = true
        pickupModeLbl.isHidden = true

        observePassengersAndDrivers()

        if Auth.auth().currentUser == nil {
            userEmailLbl.text = ""
            userAccountTypeLbl.text = ""
            userProfileImage.isHidden = true
            loginOutBtn.setTitle("Sign Up / Login", for: .normal)
        } else {
            userEmailLbl.text = Auth.auth().currentUser?.email
            userAccountTypeLbl.text = ""
            userProfileImage.isHidden = false
            loginOutBtn.setTitle("Logout", for: .normal)
        }
    }

    func observePassengersAndDrivers() {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for snap in snapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLbl.text = "PASSENGER"
                    }
                }
            }
        })

        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for snap in snapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLbl.text = "DRIVER"
                        self.pickupModeSwitch.isHidden = false

                        guard let switchStatus = snap.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool else { return }
                        self.pickupModeSwitch.isOn = switchStatus
                        self.pickupModeLbl.isHidden = false
                    }
                }
            }
        })
    }

    @IBAction func switchWasToggled(_ sender: Any) {
        if pickupModeSwitch.isOn {
            pickupModeLbl.text = "PICKUP MODE ENABLED"
            appDelegate.menuContainerVC.toggleLeftPanel()
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues(["isPickupModeEnabled": true])

        } else {
            pickupModeLbl.text = "PICKUP MODE DISABLED"
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues(["isPickupModeEnabled": false])
        }
    }


    @IBAction func signUpLoginBtnWasPressed(_ sender: Any) {
        if Auth.auth().currentUser == nil {
            let sb = UIStoryboard(name: "Main", bundle: Bundle.main)
            guard let loginVC = sb.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController else { return }
            present(loginVC, animated: true, completion: nil)

        } else {
            do {
                try Auth.auth().signOut()
                userEmailLbl.text = ""
                userAccountTypeLbl.text = ""
                userProfileImage.isHidden = true
                pickupModeLbl.text = ""
                pickupModeSwitch.isHidden = true
                loginOutBtn.setTitle("Sign Up / Login", for: .normal)
            } catch (let error) {
                print(error)
            }
        }
    }

}
