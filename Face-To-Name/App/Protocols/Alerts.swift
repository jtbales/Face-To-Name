//
//  Alerts.swift
//  Face-To-Name
//
//  Created by John Bales on 5/17/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//
//  Provides functionality for presenting alert messages synchronously and seemlessly

import UIKit

/*
 * Extends all UIViewControllers with convenient ways to display alerts that are guarented not to collide with presented views.
 */
extension UIContentContainer where Self: UIViewController {
    //Ensures that the code is only executed if the current view presented on this VC is dismissed
    func presentationSync(closure: @escaping () -> Void) {
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
    func alertMessageOkay(_ titleA: String, _ messageA: String) {
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
    func alertMessageOkay(_ alertParams: AlertParams) {
        alertMessageOkay(alertParams.title ?? "", alertParams.message ?? "")
    }
    
    //Alert with no cancel, caution you must guarantee dismissal in code
    func alertMessageNoCancel(_ titleA: String, _ messageA: String) {
        presentationSync {
            //Create alert
            let alertController = UIAlertController (
                title: titleA,
                message: messageA,
                preferredStyle: .alert)
            
            //Show alert
            self.present(
                alertController,
                animated: true,
                completion: nil)
        }
    }
    func alertMessageNoCancel(_ alertParams: AlertParams) {
        alertMessageNoCancel(alertParams.title ?? "", alertParams.message ?? "")
    }
}
