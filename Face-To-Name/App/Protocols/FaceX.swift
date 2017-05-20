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

extension Face {
    //Incorporates alerts in view for loading message and cancel option
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
                AWSS3.default().deleteS3Image(indexedFace.s3ImageAddress)
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
                    AWSS3.default().deleteS3Image(indexedFace.s3ImageAddress)
                    return nil
                }
                return nil
            }) { (alertParams) -> Void? in
                //Failure
                failureClosure(alertParams)
                return nil
            }
        } else { //Without image
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
                AWSS3.default().deleteS3Image(faceS3ImageAddress)
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

    static func deleteFaceData(_ faceToDelete: Face!, _ successClosure: @escaping () -> Void?, _ failureClosure: @escaping (AlertParams) -> Void?) {
        //Delete s3 image
        if faceToDelete.s3ImageAddress != "" {
            AWSS3.default().deleteS3Image(faceToDelete.s3ImageAddress)
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










