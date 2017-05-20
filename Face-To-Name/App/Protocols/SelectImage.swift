//
//  SelectImage.swift
//  Face-To-Name
//
//  Created by John Bales on 5/17/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit

extension UIImagePickerControllerDelegate where Self: UIViewController {
    //Prompts to select image source from Photot Library or Camera.
    func imageTypeSelect() {
        if presentedViewController == nil { //Only show if there's no other alert presented
            let alertController = UIAlertController (
                title: "Select Image Source",
                message: "",
                preferredStyle: .alert)
            
            let photoLibrary = UIAlertAction(
                title: "Photo Library",
                style: .default) { (action) in
                    self.dismiss(animated: true, completion: nil)
                    self.selectImageFromPhotoLibrary()
            }
            alertController.addAction(photoLibrary)
            
            let camera = UIAlertAction(
                title: "Camera",
                style: .default) { (action) in
                    self.dismiss(animated: true, completion: nil)
                    self.takePhotoWithCamera()
            }
            alertController.addAction(camera)
            
            let cancelAction = UIAlertAction(
                title: "Cancel",
                style: .cancel,
                handler: nil)
            alertController.addAction(cancelAction)
            
            //Show alert
            self.present(
                alertController,
                animated: true,
                completion: nil)
        }
    }
    
    //Shows Camera is avaiable, otherwise shows Photo Library
    func autoShowSelectImage() {
        //Attempt to use camera
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            takePhotoWithCamera()
        } else {
            selectImageFromPhotoLibrary()
        }
    }
    
    func takePhotoWithCamera() {
        // UIImagePickerController is a view controller that lets a user pick media from their photo library.
        let imagePickerController = UIImagePickerController()
        
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            // Only allow photo to be taken
            imagePickerController.sourceType = .camera
            imagePickerController.accessibilityActivate()
            imagePickerController.allowsEditing = false
            imagePickerController.cameraCaptureMode = .photo
            imagePickerController.cameraDevice = .front
            imagePickerController.cameraFlashMode = .off
            
            // Make sure ViewController is notified when the user picks an image.
            imagePickerController.delegate = self as? UIImagePickerControllerDelegate & UINavigationControllerDelegate
            present(imagePickerController, animated: true, completion: nil)
        } else {
            alertMessageOkay("Can't Access Camera", "Enable access to camera in Settings.")
        }
    }
    
    func selectImageFromPhotoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {
            // UIImagePickerController is a view controller that lets a user pick media from their photo library.
            let imagePickerController = UIImagePickerController()
            
            // Only allow photos to be picked, not taken.
            imagePickerController.sourceType = .photoLibrary
            
            // Make sure ViewController is notified when the user picks an image.
            imagePickerController.delegate = self as? UIImagePickerControllerDelegate & UINavigationControllerDelegate
            present(imagePickerController, animated: true, completion: nil)
        } else {
            self.alertMessageOkay("Can't Access Library", "Enable access to photo library in Settings.")
        }
    }
    
    
    
    //MARK: Unwanted Repetition
    ///////////// Please remove presentationSync() and alertMessageOkay() while still making sure this extension works. These functions are in the Alerts.swift extention
    /*
     What I've tried so far.
        1. if self is UINavigationControllerDelegate
        2. Proagating an enum AlertError: Error { case basic(title: String?, message: String?) } 
            But UIAlertAction completion closure can't throw.
    */
    
    //Ensures that the code is only executed if the current view presented on this VC is dismissed
    private func presentationSync(closure: @escaping () -> Void) {
        DispatchQueue.main.async { //Must execute UI task on main thread
            if self.presentedViewController != nil {
                self.dismiss(animated: false, completion: {
                    DispatchQueue.main.async { //Must execute UI task on main thread
                        closure()
                    }
                })
            }
            else {
                closure()
            }
        }
    }
    
    //Displays alert with okay button to cancel
    private func alertMessageOkay(_ titleA: String, _ messageA: String) {
        presentationSync {
            //Create alert
            let alertController = UIAlertController (
                title: titleA,
                message: messageA,
                preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(
                title: "Okay",
                style: .cancel,
                handler: nil)
            alertController.addAction(cancelAction)
            
            //Show alert
            self.present(
                alertController,
                animated: true,
                completion: nil)
        }
    }
}
