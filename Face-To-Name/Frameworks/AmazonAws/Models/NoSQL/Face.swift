//
//  Face.swift
//  Face-To-Name
//
//  Created by John Bales on 5/2/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation
import UIKit
import AWSDynamoDB

class Face: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    
    var _userId: String?
    var _name: String?
    var _details: String?
    var _s3ImageAddress: String?
    var _faceId: String?
    
    //MARK: accessors
    var userId: String! {
        if let userId = _userId {
            return userId
        }
        return ""
    }
    
    var name: String {
        if let name = _name {
            return name
        }
        return ""
    }
    
    var details: String {
        if let details = _details {
            return details
        }
        return ""
    }
    
    var s3ImageAddress: String {
        if let s3ImageAddress = _s3ImageAddress {
            return s3ImageAddress
        }
        return ""
    }
    
    var faceId: String {
        if let faceId = _faceId {
            return faceId
        }
        return ""
    }
    
    
    //MARK: functions
    class func dynamoDBTableName() -> String {
        
        return "facetoname-mobilehub-1679747331-faces"
    }
    
    class func hashKeyAttribute() -> String {
        
        return "_userId"
    }
    
    class func rangeKeyAttribute() -> String {
        
        return "_name"
    }
    
    override class func jsonKeyPathsByPropertyKey() -> [AnyHashable: Any] {
        return [
            "_userId" : "userId",
            "_name" : "name",
            "_details" : "details",
            "_s3ImageAddress" : "s3ImageAddress",
            "_faceId" : "faceId",
        ]
    }
}
