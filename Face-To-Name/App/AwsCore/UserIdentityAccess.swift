//
//  UserIdentityAccess.swift
//  Face-To-Name
//
//  Created by John Bales on 4/30/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation
import AWSCognito
import AWSMobileHubHelper

class UserIdentityAccess {
    
    static func getUserIdentity() -> String! {
        if let userId = AWSIdentityManager.default().identityId {
            return userId
        }
        else {
            return ""
        }
    }
    
    static func getCollectionId() -> String! {
        if let userId = AWSIdentityManager.default().identityId {
            return userId.replacingOccurrences(of: ":", with: "")
        }
        else {
            return ""
        }
    }
}
