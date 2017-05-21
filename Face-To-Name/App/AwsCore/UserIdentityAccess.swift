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

/*
 * Provides access to the User's AWS identity
 */
class UserIdentityAccess {
    /**
     * Get's the User's AWS id
     *
     * - return String!: The user's AWS id
     */
    static func getUserIdentity() -> String! {
        if let userId = AWSIdentityManager.default().identityId {
            return userId
        }
        else {
            return ""
        }
    }
    
    /**
     * Get's the User's personal AWS recognition collection id
     * using their AWS id without the ':' because that's illegal for collections
     *
     * - return String!: Collection id
     */
    static func getCollectionId() -> String! {
        if let userId = AWSIdentityManager.default().identityId {
            return userId.replacingOccurrences(of: ":", with: "")
        }
        else {
            return ""
        }
    }
}
