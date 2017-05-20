//
//  MainTabBarController.swift
//  Face-To-Name
//
//  Created by John Bales on 4/27/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit
import AWSMobileHubHelper

//Globals! XD
let bucket = "facetoname-userfiles-mobilehub-1679747331"

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //Allow user to sign if in needed
        presentSignInViewController()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
