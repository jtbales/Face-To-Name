//
//  FaceToNameAds.swift
//  Face-To-Name
//
//  Created by John Bales on 4/27/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation
import GoogleMobileAds
import AWSMobileHubHelper

/*
 * Singleton for Google Ads
 */
class FaceToNameAds: NSObject {
    
    static let sharedInstance = FaceToNameAds()
    var gadRequest: GADRequest
    //Google AdMob
    let adUnitID = "ca-app-pub-7770057470061315/6963442387"
//    let adUnitID = "ca-app-pub-3940256099942544/2934735716" //test ad unit ID, not needed with testDevices set to kGADSimulatorID
    
    override init() {
        gadRequest = GADRequest()
        gadRequest.testDevices = [ kGADSimulatorID ] //Remove before release
        //Targeting
        gadRequest.keywords = ["tech", "gadget", "digital"]
    }

    
}
