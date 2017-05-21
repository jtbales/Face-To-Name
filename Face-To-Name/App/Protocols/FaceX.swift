//
//  FaceX.swift
//  Face-To-Name
//
//  Created by John Bales on 5/18/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit
import AWSMobileHubHelper
import AWSRekognition
import AWSDynamoDB
import AWSS3

/*
 * Provides simple interface for common complex Face actions
 */
extension Face {
    /**
     * Adds new Face to User's DB, s3, and recognition collection. The whole shebang.
     *
     * - parameter view: Optional. Incorporates alerts in view for loading message and cancel option
     * - parameter name: Face.name
     * - parameter details: Face.details
     * - parameter faceImage: UIImage for face
     * - parameter successClosure(Face!): Passes full face object created
     * - parameter failureClosure(AlertParams): Passes error.
     */
    static func addFace(_ view: UIViewController? = nil, _ name: String!, _ details: String?, _ faceImage: UIImage, _ successClosure: @escaping (Face!) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        
        uploadAndIndexImage(view, name, details, faceImage, { (indexedFace) -> Void? in
            //Success
            
            //Save face to dynamoDB
            AWSDynamoDBObjectMapper.default().saveFace(indexedFace, { (faceFinal) -> Void? in
                
                //Success
                successClosure(faceFinal)
                
                return nil
            }) { (alertParams) -> Void? in
                
                //Failure
                failureClosure(alertParams)
                
                //Undo uploads
                AWSRekognition.default().deleteFaceIdsSafelyFTN(name, indexedFace.faceId)
                AWSS3.default().deleteS3Object(indexedFace.s3ImageAddress)
                
                return nil
            }
            
            return nil
        }) { (alertParams) -> Void? in
            //Failure
            failureClosure(alertParams)
            return nil
        }
        
        //Make sure faceId collection exists
        AWSRekognition.default().createCollectionFTN()
    }
    
    /**
     * Edits a Face in User's DB, s3, and recognition collection.
     *
     * - parameter view: Optional. Incorporates alerts in view for loading message and cancel option
     * - parameter name: Face.name
     * - parameter details: Face.details
     * - parameter faceImage: Optional UIImage for face
     * - parameter successClosure(Face!): Passes edited face object with new faceId if the image was changed.
     * - parameter failureClosure(AlertParams): Passes error.
     */
    static func editFace(_ view: UIViewController? = nil, _ name: String!, _ details: String?, _ faceImage: UIImage?, _ successClosure: @escaping (Face!) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        if let faceImage = faceImage { //With image
            uploadAndIndexImage(view, name, details, faceImage, { (indexedFace) -> Void? in
                //Success
                
                //Save face to dynamoDB
//                if indexedFace._details == "" { indexedFace._details = nil } //"" not allowed
                AWSDynamoDBObjectMapper.default().saveFace(indexedFace, { (faceFinal) -> Void? in
                   
                    //Success
                    successClosure(faceFinal)
                    return nil
                    
                }) { (alertParams) -> Void? in
                    
                    //Failure
                    failureClosure(alertParams)
                    
                    //Undo uploads
//                    AWSRekognition.default().deleteFaceIdsSafelyFTN(name, indexedFace.faceId) // Might remove previous faceId
                    AWSS3.default().deleteS3Object(indexedFace.s3ImageAddress)
                    return nil
                }
                return nil
                
            }) { (alertParams) -> Void? in
                //Failure
                failureClosure(alertParams)
                return nil
            }
        }
        //Without image
        else {
            let face = Face()!
            face._userId = UserIdentityAccess.getUserIdentity()
            face._name = name
            face._details = (details == "") ? " " : details //Must add space to ensure overwrite
            
            //Save face to dynamoDB
            let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig.saveBehavior = .updateSkipNullAttributes
            
            AWSDynamoDBObjectMapper.default().saveFace(face, updateMapperConfig, { (faceFinal) -> Void? in
                //Success
                successClosure(faceFinal)
                return nil
            }) { (alertParams) -> Void? in
                //Failure
                failureClosure(alertParams)
                return nil
            }
        }
    }
    
    /**
     * Uploads an image and indexes it. Adds the faceId to new face object
     *
     * - parameter view: Optional. Incorporates alerts in view for loading message and cancel option
     * - parameter name: Face.name
     * - parameter details: Face.details
     * - parameter faceImage: Optional UIImage for face
     * - parameter successClosure(Face!): Passes full face object created
     * - parameter failureClosure(AlertParams): Passes error.
     */
    private static func uploadAndIndexImage(_ view: UIViewController?, _ name: String!, _ details: String?, _ faceImage: UIImage, _ successClosure: @escaping (Face!) -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        //Upload the image
        let uploadRequest = AWSS3.default().uploadS3Image(faceImage, { (faceS3ImageAddress) -> Void? in
            //Success
            if let view = view {
                view.alertMessageNoCancel("Indexing Image...", "")
            }
            
            let face: Face = Face()
            face._userId = AWSIdentityManager.default().identityId!
            face._name = name
            face._details = (details == nil || details == "") ? " " : details
            face._s3ImageAddress = faceS3ImageAddress
            
            //Analyse image for faceId (index face)
            AWSRekognition.default().indexImageFaceFTN(faceS3ImageAddress, face, { (indexedFace) -> Void? in
                //Success
                successClosure(indexedFace)
                return nil
            }, { (alertParams) -> Void? in
                //Failure
                failureClosure(alertParams)
                //Image not needed on server
                AWSS3.default().deleteS3Object(faceS3ImageAddress)
                return nil
            })
            
            return nil
        }) { (alertParams) -> Void? in
            //Failure
            failureClosure(alertParams)
            return nil
        }
        //Display cancelable alerts on view
        if let view = view, let uploadRequest = uploadRequest {
            //Allow cancel upload
            let alertControllerCancel = UIAlertController (
                title: "Uploading...",
                message: "",
                preferredStyle: .alert)
            
            //Cancel action
            let cancelAction = UIAlertAction(
                title: "Cancel",
                style: .cancel) {(action) in
                    print ("Cancel action choosen.")
                    uploadRequest.cancel()
            }
            alertControllerCancel.addAction(cancelAction)
            
            //Show alert
            view.presentationSync {
                view.present(
                    alertControllerCancel,
                    animated: true,
                    completion: nil)
            }
        }
    }

    /**
     * Deletes all server data for face. Including s3 image, faceId (if sole referencer), and DB entry
     *
     * - parameter faceToDelete
     * - parameter successClosure()
     * - parameter failureClosure(AlertParams): Passes error.
     */
    static func deleteFaceData(_ faceToDelete: Face!, _ successClosure: @escaping () -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        //Delete s3 image
        if faceToDelete.s3ImageAddress != "" {
            AWSS3.default().deleteS3Object(faceToDelete.s3ImageAddress)
        }
        
        //Delete face meta data
        if faceToDelete.faceId != "" {
            AWSRekognition.default().deleteFaceIdsSafelyFTN(faceToDelete.name, faceToDelete.faceId)
        }
        
        //Delete DynamoDB entry
        AWSDynamoDBObjectMapper.default().deleteFace(faceToDelete, { () -> Void? in
            //Success
            successClosure()
            return nil
        }) { (alertParams) -> Void? in
            //Failure
            failureClosure(alertParams)
            return nil
        }
    }
}










