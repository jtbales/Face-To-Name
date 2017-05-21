//
//  AcquaintancesTableViewController.swift
//  Face-To-Name
//
//  Created by John Bales on 4/26/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import UIKit
import AWSDynamoDB
import AWSMobileHubHelper

class AcquaintancesTableViewController: UITableViewController {

    var acquaintanceRows: [Face]?
    var doneLoading: Bool = false
    var lastEvaluatedKey:[String : AWSDynamoDBAttributeValue]!
    var lock: NSLock?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        acquaintanceRows = []
        lock = NSLock()
        
        //Add refresh function
        self.refreshControl?.addTarget(self, action: #selector(self.refresh(_:)), for: UIControlEvents.valueChanged)
        
        self.refreshList(true)
    
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
    }
    
    func refresh(_ sender: AnyObject)
    {
        print("Refreshing")
        self.refreshList(true)
        self.refreshControl?.endRefreshing()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // return the number of rows
        if let rowCount = self.acquaintanceRows?.count {
            return rowCount;
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "acquaintanceCell", for: indexPath) as! AcquaintancesTableViewCell
        
        // Configure the cell...
        if let acquaintanceRows = self.acquaintanceRows {
            let acquaintance = acquaintanceRows[indexPath.row]
            
            cell.nameLabel.text = acquaintance.name
            cell.face = acquaintance
        }
        
        return cell
    }
    
    //Allow edits/deletions
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            print("Deleting cell at index \(indexPath.row)")
            //Assign object map details
            let cell = tableView.cellForRow(at: indexPath) as! AcquaintancesTableViewCell //Get cell details
            if let faceToDelete = cell.face {
                //Automatically remove the cell for fluidness
                self.acquaintanceRows?.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
                
                //Delete on AWS
                Face.deleteFaceData(faceToDelete, { () -> Void? in
                    //Success
                    //self.refreshList(true) //Why refresh when it's already removed from table?
                    return nil
                }, { (alertParams) -> Void? in
                    //Failure
                    self.alertMessageOkay(alertParams)
                    return nil
                })

            } else {
                self.alertMessageOkay("Can't Delete", "Cell content's empty. Refreshing List.")
                self.refreshList(true)
            }
            
        }
//        else if editingStyle == .insert {
//            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
//        }
    }
    
    //Load more by dragging
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // UITableView only moves in one direction, y axis
        let currentOffset = scrollView.contentOffset.y
        let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
        
        // Change 10.0 to adjust the distance from bottom
        if maximumOffset - currentOffset <= 10.0 {
            //Load more
            refreshList(false)
        }
    }
    
    //Refresh Table List
    func refreshList(_ startFromBeginning: Bool) {
        //verify logged in
        if !AWSIdentityManager.default().isLoggedIn {
            presentSignInViewController()
        }
        else if self.lock?.try() != nil {
            if startFromBeginning {
                self.lastEvaluatedKey = nil;
                self.doneLoading = false
            }
            //Exit if there is nothing else to load
            else if self.doneLoading {
                return
            }
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            
            //Set up DynamoDB query
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let queryExpression = AWSDynamoDBQueryExpression()
            queryExpression.exclusiveStartKey = self.lastEvaluatedKey
            queryExpression.limit = 50
            queryExpression.keyConditionExpression = "#userId = :userId"
            queryExpression.expressionAttributeNames = ["#userId": "userId"]
            queryExpression.expressionAttributeValues = [":userId": AWSIdentityManager.default().identityId!,]
            dynamoDBObjectMapper.query(Face.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask!) -> AnyObject! in
                
                if self.lastEvaluatedKey == nil {
                    self.acquaintanceRows?.removeAll(keepingCapacity: true)
                }
                
                if let paginatedOutput = task.result {
                    for item in paginatedOutput.items as! [Face] {
                        self.acquaintanceRows?.append(item)
                    }
                    
                    self.lastEvaluatedKey = paginatedOutput.lastEvaluatedKey
                    if paginatedOutput.lastEvaluatedKey == nil {
                        self.doneLoading = true
                    }
                }
                
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.tableView.reloadData()
                
                if let error = task.error as NSError? {
                    print("Error: \(error)")
                }
                
                return nil
            })
        }
    }
    
//    func generateTestData() {
//        UIApplication.shared.isNetworkActivityIndicatorVisible = true
//        
//        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
//        
//        var tasks = [AWSTask<AnyObject>]()
//        let nameArray =  ["Galaxy Invaders","Meteor Blasters", "Starship X", "Alien Adventure","Attack Ships","John","Bob","Kathrine","Alice","Tim"]
//        for i in 0..<10 {
//            let tableRow = Faces()
//            tableRow?._name = nameArray[i]
//            tasks.append(dynamoDBObjectMapper.save(tableRow!))
//        }
//        
//        AWSTask<AnyObject>(forCompletionOfAllTasks: Optional(tasks)).continueWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask) -> AnyObject? in
//            if let error = task.error as NSError? {
//                print("Error: \(error)")
//            }
//            
//            UIApplication.shared.isNetworkActivityIndicatorVisible = false
//            
//            self.refreshList(true)
//            return nil
//        })
//    }
    
    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation
    
    //Select row
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath) as! AcquaintancesTableViewCell
        print("Selected cell with name \(cell.nameLabel.text ?? "nil")")
        performSegue(withIdentifier: "EditAcquaintanceShowSegue", sender: cell)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if let destinationViewController = segue.destination as? EditAcquaintanceViewController {
            let cell = sender as? AcquaintancesTableViewCell
            destinationViewController.faceToEdit = cell?.face
        }
    }
    
    //MARK: Actions
    @IBAction func unwindToAcquaintList(segue: UIStoryboardSegue) {
        refreshList(true)
    }

}

class AcquaintancesTableViewCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    //Non-visable data
    var face: Face?
}









