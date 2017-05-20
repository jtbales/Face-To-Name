//
//  DynamoDBObjectMapper.swift
//  Face-To-Name
//
//  Created by John Bales on 5/18/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation
import AWSDynamoDB

extension AWSDynamoDBObjectMapper {
    func saveFace(_ face: Face?, _ config: AWSDynamoDBObjectMapperConfiguration?, _ successClosure: @escaping (Face!) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        if let face = face {
            //Save face values in DynamoDB
            //Attempt save
            self.save(face, configuration: config, completionHandler: {(error: Error?) -> Void in
                if let error = error as NSError? {
                    //Failure
                    var alertParams: AlertParams?
                    if error.domain == AWSDynamoDBErrorDomain, let code = AWSDynamoDBErrorType(rawValue: error.code) {
                        switch code {
                        case .conditionalCheckFailed:
                            alertParams = AlertParams(title: "Invalid Entry", message: error.userInfo["Message"] as? String ?? "")
                        default:
                            alertParams = AlertParams(title: "Save Failed", message: error.userInfo["Message"] as? String ?? "Please try again")
                        }
                    }
                    print("Amazon DynamoDB Save Error: \(error)")
                    failureClosure(alertParams ?? AlertParams(title: "Error", message: "\(error.localizedDescription)"))
                    return
                }
                //Success
                print("Face for \(face.name)) saved.")
                successClosure(face)
            })
        } else {
            print("face object nil for saveFace()")
        }
    }
    func saveFace(_ face: Face?, _ successClosure: @escaping (Face!) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        saveFace(face, AWSDynamoDBObjectMapperConfiguration(), { (savedFace) -> Void? in
            //Success
            successClosure(savedFace)
            return nil
        }) { (alertParams) -> Void? in
            //Failure
            failureClosure(alertParams)
            return nil
        }
    }
    
    //Delete face entry from DynamoDB
    func deleteFace(_ faceToDelete: Face!, _ successClosure: @escaping () -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        self.remove(faceToDelete, completionHandler: { (error: Error?) in
            if let error = error as NSError? {
                //Failure
                var alertParams: AlertParams?
                if error.domain == AWSDynamoDBErrorDomain, let code = AWSDynamoDBErrorType(rawValue: error.code) {
                    switch code {
                    case .conditionalCheckFailed:
                        alertParams = AlertParams(title: "Invalid Entry", message: error.userInfo["Message"] as? String ?? "")
                    default:
                        alertParams = AlertParams(title: "Delete Failed", message: error.userInfo["Message"] as? String ?? "Please try again.")
                    }
                }
                print("Amazon DynamoDB Deletion Error: \(error)")
                failureClosure(alertParams ?? AlertParams(title: "Delete Failed", message: error.userInfo["Message"] as? String ?? error.localizedDescription))
            } else {
                print("Deletion of \(faceToDelete.name) sucessful")
            }
        })
    }
    
    //Query for acquaintance with the name
    func queryFaceData(_ nameToQuery: String?, _ successClosure: @escaping (Face!) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        if let nameToQuery = nameToQuery {
            let objectMapper = AWSDynamoDBObjectMapper.default()
            let queryExpression = AWSDynamoDBQueryExpression()
            
            queryExpression.keyConditionExpression = "userId = :userIdDefault AND #name = :nameToQuery"
            queryExpression.expressionAttributeNames = [
                "#name" : "name"];
            queryExpression.expressionAttributeValues = [
                ":userIdDefault" : UserIdentityAccess.getUserIdentity(),
                ":nameToQuery" : nameToQuery];
            
            var matchingFace: Face? = nil
            
            objectMapper.query(Face.self, expression: queryExpression, completionHandler: { (result: AWSDynamoDBPaginatedOutput?, error: Error?) -> Void in
                if let error = error as NSError? {
                    print("Amazon DynamoDB Query Error: \(error)")
                    failureClosure(AlertParams(title: "Search Failed", message: error.userInfo["Message"] as? String ?? "Failed to check if the name used already exists. Please try again."))
                } else {
                    if let result = result {
                        if let firstMatch = result.items.first {
                            matchingFace = firstMatch as? Face
                        }
                    }
                    //Matching name found
                    if matchingFace != nil {
                        successClosure(matchingFace!)
                    }
                    else {
                        failureClosure(AlertParams(title: "Name not found", message: "Could not find any record of \(nameToQuery)"))
                    }
                }
            })
        } else {
            print("Name parameter to query was nil")
        }
    }
    
    //Queries by faceId. Passes list of matching Faces to successClosure
    func queryFaceData(faceId: String!, _ successClosure: @escaping ([Face]) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        
        queryExpression.indexName = "FaceId"
        queryExpression.keyConditionExpression = "userId = :userIdDefault AND faceId = :faceId"
        queryExpression.expressionAttributeValues = [
            ":userIdDefault" : UserIdentityAccess.getUserIdentity(),
            ":faceId" : faceId];
        
        objectMapper.query(Face.self, expression: queryExpression, completionHandler: { (result: AWSDynamoDBPaginatedOutput?, error: Error?) -> Void in
            if let error = error as NSError? {
                print("Amazon DynamoDB Query Error: \(error)")
                failureClosure(AlertParams(title: "Search Failed", message: error.userInfo["Message"] as? String ?? error.localizedDescription))
            } else {
                if let result = result {
                    if let matchingFaces = result.items as? [Face] {
                        successClosure(matchingFaces)
                    }
                }
                else {
                    failureClosure(AlertParams(title: "Match not found", message: "Not close enough to any know acquaintance."))
                }
            }
        })
    }
    
    //Query for acquaintance with the name. Check if it exists
    func faceNameExists(_ nameToQuery: String?, _ successClosure: @escaping (Bool) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        if let nameToQuery = nameToQuery {
            let objectMapper = AWSDynamoDBObjectMapper.default()
            let queryExpression = AWSDynamoDBQueryExpression()
            
            queryExpression.keyConditionExpression = "userId = :userIdDefault AND #name = :nameToQuery"
            queryExpression.expressionAttributeNames = [
                "#name" : "name"];
            queryExpression.expressionAttributeValues = [
                ":userIdDefault" : UserIdentityAccess.getUserIdentity(),
                ":nameToQuery" : nameToQuery];
            
            var matchingFace: Face? = nil
            
            objectMapper.query(Face.self, expression: queryExpression, completionHandler: { (result: AWSDynamoDBPaginatedOutput?, error: Error?) -> Void in
                if let error = error as NSError? {
                    print("Amazon DynamoDB Query Error: \(error)")
                    failureClosure(AlertParams(title: "Search Failed", message: error.userInfo["Message"] as? String ?? "Failed to check if the name used already exists. Please try again."))
                } else {
                    if let result = result {
                        if let firstMatch = result.items.first {
                            matchingFace = firstMatch as? Face
                        }
                    }
                    //Matching name found
                    if matchingFace != nil {
                        successClosure(true)
                    }
                    else {
                        successClosure(false)
                    }
                }
            })
        } else {
            print("Name parameter to query was nil")
        }
    }
}
