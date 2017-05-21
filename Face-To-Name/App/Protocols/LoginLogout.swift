//
//  LoginLogout.swift
//  Face-To-Name
//
//  Created by John Bales on 5/18/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit
import AWSCognito
import AWSMobileHubHelper

extension UIContentContainer where Self: UIViewController {
    //Send to Sign in view if not logged in
    func presentSignInViewController() {
        if !AWSIdentityManager.default().isLoggedIn {
            let storyboard = UIStoryboard(name: "SignIn", bundle: nil)
            let viewController = storyboard.instantiateViewController(withIdentifier: "SignIn")
            self.present(viewController, animated: false, completion: nil)
        }
    }
}
