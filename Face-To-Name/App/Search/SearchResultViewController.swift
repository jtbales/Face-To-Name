//
//  SearchResultViewController.swift
//  Face-To-Name
//
//  Created by John Bales on 5/10/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit
import GoogleMobileAds
import AWSRekognition
import AWSDynamoDB
import AWSS3

class SearchResultViewController: UIViewController {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var faceImageView: UIImageView!
//    @IBOutlet weak var bannerView: GADBannerView!
    
    var matchingFaces: [AWSRekognitionFaceMatch]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //TODO results show a box around each person's face and their name
        //Displays the data from the frist match in photo
        displayFirstMatch(matchingFaces)
        
        //Google AdMob
//        bannerView.adUnitID = FaceToNameAds.sharedInstance.adUnitID
//        bannerView.rootViewController = self
//        let gadReqest = FaceToNameAds.sharedInstance.gadRequest
//        bannerView.load(gadReqest)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //
    func displayFirstMatch(_ matches: [AWSRekognitionFaceMatch]?, _ startIndex: Int = 0) {
        if let matches = matches {
            //Narrow Down
            var nextStartIndex = 0
            var firstMatch: AWSRekognitionFaceMatch?
            for i in startIndex ... matches.count {
                if matches[i].face?.faceId != nil {
                    firstMatch = matches[i] //First valid match
                    nextStartIndex = i + 1
                    break
                }
            }
            //Test match
            if let match = firstMatch {
                if let faceId = match.face?.faceId {
                    
                    //Query for the face
                    AWSDynamoDBObjectMapper.default().queryFaceData(faceId: faceId, { (faceResults) -> Void? in
                        
                        //Success
                        if faceResults.count == 0 {
                            //This indicates a stray faceId. Delete it.
                            AWSRekognition.default().deleteFaceIdsUNSAFE_FTN([faceId])
                            //Then attempt next match
                            self.displayFirstMatch(matches, nextStartIndex)
                        } else {
                            self.displayFace(faceResults[0], match.similarity)
                        }
                        
                        return nil
                    }, { (alertParams) -> Void? in
                        //Failure
                        self.alertMessageOkay(alertParams)
                        return nil
                    })
                    
                } else {
                    print("faceId was nil for displayFirstMatch")
                    self.alertMessageOkay("No Match Found", "This person is not likely listed as an aquaintance.")
                }
            } else {
                print("AWSRekognitionFaceMatch for displayFirstMatch was nil")
            }
        } else {
            self.alertMessageOkay("Not Found", "Empty result. Try again with another photo.")
        }
        
    }
    
    func displayFace(_ face: Face!, _ similarity: NSNumber?) {
        DispatchQueue.main.async {
            self.nameLabel.text = face.name
            
            if let similarity = similarity {
                let nf = NumberFormatter()
                nf.numberStyle = .decimal
                self.detailsLabel.text = "Similarity: \(nf.string(from: similarity) ?? "Unavailable")%\n"
            }
            
            self.detailsLabel.text?.append("Details: \(face.details)") //Append after confidence percentage
        }
            
        if face.s3ImageAddress == "" {
            print("s3ImageAddress not provided for \(face.name)")
            return
        }
        
        AWSS3.default().downloadS3Image(face.s3ImageAddress, { (downloadedFileURL) -> Void? in
            //Success
            
            //Show image
            DispatchQueue.main.async { //Must modify UI on main thread
                self.faceImageView.image = UIImage(fileURL: downloadedFileURL)
            }
            
            return nil
        }, { (alertParams) -> Void? in
            //Failure
            self.alertMessageOkay(alertParams)
            return nil
        })
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
