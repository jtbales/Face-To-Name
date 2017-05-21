//
//  AddAcquaintanceViewController.swift
//  Face-To-Name
//
//  Created by John Bales on 4/26/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit
import GoogleMobileAds
import AWSMobileHubHelper
import AWSRekognition
import AWSDynamoDB
import AWSS3

class AddAcquaintanceViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var detailsTextField: UITextField!
//    @IBOutlet weak var bannerView: GADBannerView!
    @IBOutlet weak var faceImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var doneBarButton: UIBarButtonItem!
    var saving = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Google AdMob
//        bannerView.adUnitID = FaceToNameAds.sharedInstance.adUnitID
//        bannerView.rootViewController = self
//        let gadReqest = FaceToNameAds.sharedInstance.gadRequest
//        bannerView.load(gadReqest)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //Allow user to sign if in needed
        presentSignInViewController()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: UIImagePickerControllerDelegate
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // Dismiss the picker if the user canceled.
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        // The info dictionary may contain multiple representations of the image. You want to use the original.
        guard let selectedImage = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("Expected a dictionary containing an image, but was provided the following: \(info)")
        }
        
        // Set ImageView to display the selected image.
        faceImageView.image = selectedImage
        
        // Dismiss the picker.
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: Functions
    func addAcquaintance(_ faceImage: UIImage) {
        //Animation
        progressView.setProgress(0, animated: true)
        progressView.isHidden = false
        
        Face.addFace(self, nameTextField.text?.trimmingCharacters(in: [" "]) ?? "", detailsTextField.text, faceImage, { (face) -> Void? in
            //Success
            self.presentationSync {
                self.performSegue(withIdentifier: "unwindToAcquaintList", sender: self)
            }
            return nil
        }) { (alertParams) -> Void? in
            //Failure
            self.alertMessageOkay(alertParams)
            
            //Reset UI
            self.progressView.isHidden = true
            self.saveStopping()
            return nil
        }
    }
        
    //MARK: Actions
    @IBAction func imageTypeSelect(_ sender: UITapGestureRecognizer) {
        imageTypeSelect()
    }
    
    @IBAction func done(_ sender: UIBarButtonItem) {
        if !AWSIdentityManager.default().isLoggedIn {
            presentSignInViewController()
        }
        else if !saving {
            //Name Required
            //print("Name = \(nameTextField.text ?? "Nil Name Text Field")")
            if (nameTextField.text == nil || (nameTextField.text!.trimmingCharacters(in: [" "])) == "") {
                self.alertMessageOkay("Name Required", "Please enter a name to remember the person by.")
            }
                //Photo Required
            else if faceImageView.image == nil || faceImageView.image == #imageLiteral(resourceName: "NoPhotoSelected") {
                self.alertMessageOkay("Photo Required", "Make sure the image has a clear view of the person's face and no one else's.")
            }
            else {
                //Ensure sequence
                saveStarting()
                
                //Start animations
                progressView.setProgress(0, animated: true)
                
                //Check if name is already taken
                AWSDynamoDBObjectMapper.default().faceNameExists(nameTextField.text!.trimmingCharacters(in: [" "]), { (faceDataExists) -> Void? in
                    if faceDataExists {
                        self.alertMessageOkay("Name Taken", "You already have an acquaintance with that name.")
                    } else {
                        //Success
                        //Try to upload Image and add acquaintance
                        self.addAcquaintance(self.faceImageView.image!)
                    }
                    return nil
                }, { (alertParams) -> Void? in
                    //Failure
                    self.alertMessageOkay(alertParams)
                    self.saveStopping()
                    return nil
                })
            }
        } else {
            print("Currently saving. Done trigger skipped.")
        }
    }
    
    func saveStarting() {
        saving = true
        doneBarButton.isEnabled = false
        alertMessageNoCancel("Loading...", "")
    }
    func saveStopping() {
        saving = false
        doneBarButton.isEnabled = true
    }
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
