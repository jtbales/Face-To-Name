//
//  DynamoDBObjectMapper.swift
//  Face-To-Name
//
//  Created by John Bales on 5/18/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation
import AWSDynamoDB

/*
 * Provides DB methods particular to Face-To-Name's DB Objects
 */
extension AWSDynamoDBObjectMapper {
    /**
     * Saves face object to DB
     *
     * - parameter face: face to be saved
     * - parameter config: optional configuration for save
     * - parameter successClosure(Face!): Passes face object given in parameter if saved successfully.
     * - parameter failureClosure(AlertParams): Passes error.
     */
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
    
    /**
     * Delete face entry from DynamoDB
     *
     * - parameter faceToDelete: face object to delete from DB
     * - parameter successClosure()
     * - parameter failureClosure(AlertParams): Passes error.
     */
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
    
    /**
     * Query for acquaintance with the name
     *
     * - parameter nameToQuery
     * - parameter successClosure(Face!): Passes the face that was found in DB
     * - parameter failureClosure(AlertParams): Passes error.
     */
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
    
    /**
     * Queries by faceId for Face Table DB references
     *
     * - parameter faceId: faceId to query by
     * - parameter successClosure([Face]): Passes Face DB references
     * - parameter failureClosure(AlertParams): Passes error.
     */
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
    
    /**
     * Query for acquaintance with the name. Check if it exists in Face table
     *
     * - parameter nameToQuery
     * - parameter successClosure(Bool): Passes true if the name is referenced in Face table
     * - parameter failureClosure(AlertParams): Passes error.
     */
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
