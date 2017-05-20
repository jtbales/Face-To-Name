//
//  SettingsViewController.swift
//  Face-To-Name
//
//  Created by John Bales on 4/28/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit
import AWSMobileHubHelper

class SettingsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //MARK: Login and Logout
    func handleLogout() {
        if (AWSIdentityManager.default().isLoggedIn) {
            AWSIdentityManager.default().logout(completionHandler: {(result: Any?, error: Error?) in
                self.navigationController!.popToRootViewController(animated: false)
                //                self.setupRightBarButtonItem()
                self.presentSignInViewController()
            })
//             print("Logout Successful: \(signInProvider.getDisplayName)");
        } else {
            assert(false)
        }
    }
    
    //MARK: Actions
    
    @IBAction func signOut(_ sender: UIBarButtonItem) {
        handleLogout()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
