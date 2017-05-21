//
//  S3.swift
//  Face-To-Name
//
//  Created by John Bales on 5/18/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation
import AWSS3

/*
 * AWSS3 Image methods. Delete, Upload, Download
 */
extension AWSS3 {
    /**
     * Delete attempt for s3Image at address
     *
     * - parameter s3ObjectAddress: s3 Address for the object to delete
     */
    func deleteS3Object(_ s3ObjectAddress: String!) {
        let delete = AWSS3DeleteObjectRequest()
        delete?.bucket = bucket
        delete?.key = s3ObjectAddress
        
        let response = self.deleteObject(delete!)
        //Peform deletion silently
        response.continueWith { (task) -> Any? in
            print("Attempted delete s3Image at \(s3ObjectAddress)")
            if let error = task.error {
                print(error)
            } else {
                print("Deleted s3Image successfully")
            }
            return nil
        }
    }
    
    /**
     * Uploads UIImage to s3
     * Steps:
     *  1. Converts to PNG
     *  2. Saves PNG to file
     *  3. Attempts Upload
     *
     * - parameter faceImage: image to upload
     * - parameter successClosure(String!): Passes s3ObjectAddress
     * - parameter failureClosure(AlertParams): Passes error.
     * - returns AWSS3TransferManagerUploadRequest? if request is started. Can be used to cancel upload or monitor progress.
     */
    func uploadS3Image(_ faceImage: UIImage, _ successFunc: @escaping (String!) -> Void?, _ failureFunc: @escaping (AlertParams) -> Void?) -> AWSS3TransferManagerUploadRequest? {
        //Set details for file that will be transfered
        let uploadDirName = "upload"
        let fileName = "facetoname" + String(faceImage.hashValue) + String(NSDate.hash()) + ".png"
        print("fileName: " + fileName)
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uploadDirName, isDirectory: true)?.appendingPathComponent(fileName)
        if let fileURL = fileURL {
            let filePath = fileURL.deletingLastPathComponent() //Just directory left
            let imageData = UIImagePNGRepresentation(faceImage)
            //Debug
            print("File Path = \(filePath)")
            print("File URL = \(fileURL)")
            
            //Remove any file where the upload directory should be
            do {
                try FileManager.default.removeItem(at: NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uploadDirName, isDirectory: false)!)
            } catch {
                print("Failed to remove upload file that is stopping the creation of an upload directory. \(error)")
            }
            //Make sure directory exists
            if !FileManager.default.fileExists(atPath: filePath.absoluteString) {
                print("Upload path doesn't exists. Creating path: \(filePath)")
                do {
                    try FileManager.default.createDirectory(at: filePath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create directory for upload png: \(error)")
                }
            }
            
            //Delete file if already there
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Failed to remove existing image file. Not an issue if none exists. \(error)")
            }
            
            //Save image png locally
            do {
                try imageData!.write(to: fileURL, options: [.atomic] )
            } catch {
                print("PNG save data error: \(error)")
                failureFunc(AlertParams(title: "Saving Image Faild", message: "Failed to write image data to local directory."))
                return nil
            }

            //Upload png
            let uploadRequest = AWSS3TransferManagerUploadRequest()
            uploadRequest?.bucket = bucket
            uploadRequest?.key = "private/" + UserIdentityAccess.getUserIdentity() + "/acquaintances/" + fileName
            uploadRequest?.body = fileURL
            
            if let uploadRequest = uploadRequest {
                //Transfer the upload request
                let transferManager = AWSS3TransferManager.default()
                transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AnyObject>) -> Any? in
                    if let error = task.error as NSError? {
                        if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                            switch code {
                            case .cancelled, .paused:
                                failureFunc(AlertParams(title: "Upload Canceled", message: ""))
                            default:
                                print("Error uploading: \(uploadRequest.key ?? "") Error: \(error)")
                                failureFunc(AlertParams(title: "Upload Faild", message: "Could not upload image. \(error.userInfo["Message"] as? String ?? error.localizedDescription)"))
                            }
                        } else {
                            print("Error uploading: \(uploadRequest.key ?? "") Error: \(error)")
                            failureFunc(AlertParams(title: "Upload Faild", message: "Could not upload image. \(error.userInfo["Message"] as? String ?? error.localizedDescription)"))
                        }
                        return nil
                    }
                    print("Upload complete for: \(uploadRequest.key ?? "")")
                    
                    if let faceS3ImageAddress = uploadRequest.key {
                        //Success
                        successFunc(faceS3ImageAddress)
                    }
                    else {
                        failureFunc(AlertParams(title: "Upload Failed", message: "Could not upload image, please try again."))
                    }
                    return nil
                })
                //Show progress of upload
                //                uploadRequest.uploadProgress = {(bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
                //                    DispatchQueue.main.async(execute: {() -> Void in
                //                        //Update progress
                //                        if uploadRequest.state != .running {
                //
                //                        }
                //                        else if totalBytesExpectedToSend > 0 {
                //                            self.progressView.setProgress(Float(Double(totalBytesSent) / Double(totalBytesExpectedToSend)), animated: true)
                //                            self.progressView.isHidden = false
                //                            print("Set progress to \(self.progressView.progress)")
                //                        }
                //                    })
                //                }
                return uploadRequest
            }
            return nil
        }
        return nil
    }
    
    /**
     * Downloads image at address
     *
     * - parameter s3ImageAddress: s3 Image Address to get download
     * - parameter successClosure(URL!): Passes the downloadingFileURL located on local device
     * - parameter failureClosure(AlertParams): Passes error.
     */
    func downloadS3Image(_ s3ImageAddress: String!, _ successFunc: @escaping (URL!) -> Void?, _ failureFunc: @escaping (AlertParams) -> Void?) {
        //Asynchronously load the face image
        let downloadRequest = AWSS3TransferManagerDownloadRequest()
        downloadRequest?.bucket = bucket
        downloadRequest?.key = s3ImageAddress
        downloadRequest?.downloadingFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(s3ImageAddress)
        
        //TODO keep image saved. Check if still there, use if is. Delete when changed. Reduces loading.
        //Delete file if already there
        do {
            try FileManager.default.removeItem(at: (downloadRequest?.downloadingFileURL.absoluteURL)!)
        } catch {
            print("Failed to remove existing image file. Not an issue if none exists. \(error)")
        }
        
        //Make sure directory exists
        if let downloadDirectory = downloadRequest?.downloadingFileURL.deletingLastPathComponent() {
            if !FileManager.default.fileExists(atPath: downloadDirectory.absoluteString) {
                print("Download path doesn't exists. Creating path: \(downloadDirectory.absoluteString)")
                do {
                    try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create directory for upload png: \(error)")
                }
            }
        } else {
            print("When downloading s3 image downloadRequest?.downloadingFileURL.deletingLastPathComponent() was nil")
        }
        
        let transferManager = AWSS3TransferManager.default()
        if let downloadRequest = downloadRequest {
            transferManager.download(downloadRequest).continueWith(block: { (task) -> Void? in
                if let error = task.error as NSError? {
                    if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                        switch code {
                        case .cancelled, .paused:
                            break
                        default:
                            print("Error downloading: \(downloadRequest.key ?? "") Error: \(error)")
                            failureFunc(AlertParams(title: "Download Faild", message: error.userInfo["Message"] as? String ?? "Could not download image."))
                        }
                    } else {
                        print("Error downloading: \(downloadRequest.key ?? "") Error: \(error)")
                        failureFunc(AlertParams(title: "Download Faild", message: error.userInfo["Message"] as? String ?? "Could not download image."))
                    }
                } else {
                    //Succesfull
                    print("Download complete for: \(downloadRequest.key ?? "")")
                    successFunc(downloadRequest.downloadingFileURL)
                }
                return nil
            })
        } else {
            print("downloadRequest was somehow nil")
        }
    }
}

extension UIImage {
    //init UIImage(URL!)
    convenience init?(fileURL: URL!) {
        //Get image data
        if let data = NSData.init(contentsOf: fileURL) {
            self.init(data: data as Data)
        } else {
            print("downloadedFileData is nil")
            return nil
        }
    }
}








