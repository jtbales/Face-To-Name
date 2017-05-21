//
//  Rekognition.swift
//  Face-To-Name
//
//  Created by John Bales on 5/18/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation
import AWSRekognition
import AWSDynamoDB

/*
 * Provides Rekognition methods
*/
extension AWSRekognition {
    //FTN stands for Face to Name
    
    //Silently deletes faces of array of faceId strings
    //************Caution************ Multiple acquaintances may reference the same faceId. Recommended to just use the save method
    func deleteFaceIdsUNSAFE_FTN(_ faceIds: [String]?) {
        let deleteFaces = AWSRekognitionDeleteFacesRequest()
        deleteFaces?.collectionId = UserIdentityAccess.getCollectionId()
        deleteFaces?.faceIds = faceIds
        
        let response = self.deleteFaces(deleteFaces!)
        response.continueWith { (task) -> Void? in
            print("Attempted delete faces on \(faceIds ?? [""])")
            if let error = task.error {
                print(error)
            } else {
                print("Deleted faces successfully")
            }
            return nil
        }
    }
    
    /**
     * Only deletes the faceId if there is no other entry
     * in the DB reference in the same faceId
     *
     * - parameter name: name asociated with the faceId to delete. Excludes this name when checking for references to faceId.
     * - parameter faceId: faceId to delete
     */
    func deleteFaceIdsSafelyFTN(_ name: String?, _ faceId: String!) {
        AWSDynamoDBObjectMapper.default().queryFaceData(faceId: faceId, { (matchingFaces) -> Void? in
            //Success
            //Check for another reference to face id
            var externalReferenceToFaceId = false
            for matchingFace in matchingFaces {
                if matchingFace.name != name {
                    externalReferenceToFaceId = true
                    break
                }
            }
            //Delete faceId if no other reference is found
            if !externalReferenceToFaceId {
                self.deleteFaceIdsUNSAFE_FTN([faceId])
            } else {
                print("Not deleting faceId \(faceId) because it have other DB references.")
            }
            return nil
        }) { (alertParams) -> Void? in
            //Silent Failure
            //TODO Investigate if there is a need to not be silent?
            return nil
        }
    }
    
    //Create collection using the User's identity
    func createCollectionFTN() {
        let createCollection = AWSRekognitionCreateCollectionRequest()
        createCollection?.collectionId = UserIdentityAccess.getCollectionId()
        
        if let createCollection = createCollection {
            let response = self.createCollection(createCollection)
            response.continueWith(block: { (task) -> Any? in
                if let error = task.error {
                    print("Failed to create image collection \(error)")
                }
                if let result = task.result { //Success
                    if let collectionArn = result.collectionArn {
                        print("CollectionArn: " + collectionArn);
                    }
                }
                return nil
            })
        }
    }
    
    /**
     * Indexes an image in s3
     *
     * - parameter imageAddress: s3 Image Address to index
     * - parameter face: optional face object to add the resulting faceId to.
     * - parameter successClosure(Face!): Passes face object given in parameter or new face if not provided. face will have faceId
     * - parameter failureClosure(AlertParams): Passes error.
     */
    func indexImageFaceFTN(_ imageAddress: String!, _ face: Face?, _ successClosure: @escaping (Face!) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        let indexFaces = AWSRekognitionIndexFacesRequest()!
        indexFaces.collectionId = UserIdentityAccess.getCollectionId()
        indexFaces.image = AWSRekognitionImage()!
        indexFaces.image!.s3Object = AWSRekognitionS3Object()!
        indexFaces.image!.s3Object!.bucket = bucket
        indexFaces.image!.s3Object!.name = imageAddress
        var faceIdResult: String?
        
        let response = self.indexFaces(indexFaces)
        response.continueWith(block: { (task) -> Any? in
            if let error = task.error as NSError? {
                var alertParams: AlertParams?
                if error.domain == AWSRekognitionErrorDomain, let code = AWSRekognitionErrorType(rawValue: error.code) {
                    switch code {
                    case .accessDenied:
                        alertParams = AlertParams(title: "Access Denied", message: "You do not have permission to index image.")
                    case .imageTooLarge:
                        alertParams = AlertParams(title: "Image Too Large", message: "Indexing does not support the attempted size of upload.")
                    case .invalidImageFormat:
                        alertParams = AlertParams(title: "Invalid Image Format", message: error.userInfo["Message"] as? String ?? error.localizedDescription)
                    case .invalidParameter:
                        alertParams = AlertParams(title: "Invalid Parameter", message: error.userInfo["Message"] as? String ?? error.localizedDescription)
                    default:
                        alertParams = AlertParams(title: "Scan Failed", message: "Failed to index image. \(error.userInfo["Message"] as? String ?? error.localizedDescription)")
                    }
                }
                print("Failed to index image \(error)")
                failureClosure(alertParams ?? AlertParams(title: "Error", message: "\(error.localizedDescription)"))
            }
            else if let result = task.result { //Success
                if let faceRecords = result.faceRecords {
                    if faceRecords.count == 1 {
                        for faceRecord in faceRecords {
                            faceIdResult = faceRecord.face?.faceId
                        }
                        //Pass result to success functions
                        if let face = face {
                            face._faceId = faceIdResult
                            successClosure(face)
                        } else {
                            let face = Face()
                            face?._faceId = faceIdResult
                            face?._s3ImageAddress = imageAddress
                            successClosure(face!)
                        }
                    } else if faceRecords.count > 1 {
                        //TODO Allow the user to select which face is the correct one.
                        failureClosure(AlertParams(title: "Too many faces", message: "Please retry with only ONE face visiable in image."))
                    } else {
                        failureClosure(AlertParams(title: "No face found", message: "Please retry with a clearer image of the face."))
                    }
                }
            } else {
                failureClosure(AlertParams(title: "No Response", message: "Please try again."))
            }
            return nil
        })
    }
    
    /**
     *  Searches by UIImage for matching faces within user's collection
     *
     * - parameter faceImage: UIImage to search
     * - parameter successClosure([AWSRekognitionFaceMatch]): Passes face matches found in the image
     * - parameter failureClosure(AlertParams): Passes error.
     */
    func searchForFacesFTN(_ faceImage: UIImage, _ successClosure: @escaping ([AWSRekognitionFaceMatch]) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        //Search Faces Request
        let searchFacesByImageReq = AWSRekognitionSearchFacesByImageRequest()
        searchFacesByImageReq?.faceMatchThreshold = 70
        searchFacesByImageReq?.collectionId = UserIdentityAccess.getCollectionId()
        
        //Encoded image
        let rekImage = AWSRekognitionImage()
        rekImage?.bytes = UIImageJPEGRepresentation(faceImage, 0.5)
        rekImage?.s3Object?.bucket = bucket
        searchFacesByImageReq?.image = rekImage
        
        if let searchFacesByImageReq = searchFacesByImageReq {
            let searchFacesByImageResp = self.searchFaces(byImage: searchFacesByImageReq)
            searchFacesByImageResp.continueWith(block: { (task) -> Any? in
                if let error = task.error as NSError? { //Fails
                    print(error)
                    var alertParams: AlertParams?
                    if error.domain == AWSRekognitionErrorDomain, let code = AWSRekognitionErrorType(rawValue: error.code) {
                        switch code {
                        case .accessDenied:
                            alertParams = AlertParams(title: "Access Denied", message: "You do not have permission to index image.")
                        case .imageTooLarge:
                            alertParams = AlertParams(title: "Image Too Large", message: "Indexing does not support the attempted size of upload.")
                        case .invalidImageFormat:
                            alertParams = AlertParams(title: "Invalid Image Format", message: error.userInfo["Message"] as? String ?? error.localizedDescription)
                        case .invalidParameter:
                            alertParams = AlertParams(title: "Invalid Parameter", message: error.userInfo["Message"] as? String ?? error.localizedDescription)
                        default:
                            alertParams = AlertParams(title: "Scan Failed", message: "Failed to index image. \(error.userInfo["Message"] as? String ?? error.localizedDescription)")
                        }
                    }
                    print("Failed to rek search image \(error)")
                    failureClosure(alertParams ?? AlertParams(title: "Analysis Failed", message: "\(error.localizedDescription)"))
                }
                else if let result = task.result { //Success
                    if let faceMatches = result.faceMatches {
                        if faceMatches.count == 0 {
                            failureClosure(AlertParams(title: "Unknow Person", message: "Not a close enough resemblance. Add them to your list."))
                        } else {
                            successClosure(faceMatches)
                        }
                    }
                } else {
                    failureClosure(AlertParams(title: "No Response", message: "Result was empty"))
                }
                return nil
            })
        }
    }

}
