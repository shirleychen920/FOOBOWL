//
//  OrderView.swift
//  Calculator
//
//  Created by Wang Jingtao on 5/30/16.
//  Copyright © 2016 ShirleyChen. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreData

class OrderView: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, UISearchBarDelegate, CBPeripheralManagerDelegate, UITextViewDelegate
{
    
    @IBOutlet weak var Button: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    private var touched:Bool = false
    private var HaveSent:Bool = false
      
    @IBAction func FinishedAction(sender: AnyObject) {
        if Button.titleLabel!.text == "Finish" {
            touched = true
            HaveSent = false
        self.tableView.reloadData()
        Button.setTitle("Send", forState: .Normal)
        }
        else if Button.titleLabel!.text == "Send"{
            print("sending menu")
            if HaveSent == false{
            peripheralManager!.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey : [transferServiceUUID_1]
                ])
            } else {
                peripheralManager?.stopAdvertising()
                print("stop advertising")
                peripheralManager!.startAdvertising([
                    CBAdvertisementDataServiceUUIDsKey : [transferServiceUUID_1]
                    ])
            }
        }
    }
    var friendsArray = [FriendItem]()
    var filteredFriends = [FriendItem]()
    var selected = Set<String>()
    var peripheralManager: CBPeripheralManager?
    var  transferCharacteristic = CBMutableCharacteristic?()
    
    @IBOutlet weak var advertisingButton: UIButton!
    private var dataToSend: NSData?
    private var sendDataIndex: Int?
    
    
    
    override func viewDidLoad()
    {
        peripheralManager = CBPeripheralManager ( delegate: self, queue: nil)
        super.viewDidLoad()
        self.tableView.allowsMultipleSelection = true
        self.friendsArray += [FriendItem(name: "Sushi")]
        self.friendsArray += [FriendItem(name: "Ramen")]
        self.friendsArray += [FriendItem(name: "Kentucky Fried Chicken")]
        self.friendsArray += [FriendItem(name: "Peaking Duck")]
        self.friendsArray += [FriendItem(name: "Wonton Soup")]
        self.friendsArray += [FriendItem(name: "Boiled Dumplings")]
        self.friendsArray += [FriendItem(name: "Fried Dumplings")]
        self.friendsArray += [FriendItem(name: "Beef Noodle Soup")]
        self.friendsArray += [FriendItem(name: "Orange Chicken")]
        self.friendsArray += [FriendItem(name: "Bulgogi")]
        self.friendsArray += [FriendItem(name: "Tofu Soup")]
        self.friendsArray += [FriendItem(name: "Pho")]
        self.friendsArray += [FriendItem(name: "Fried Rice")]
        self.friendsArray += [FriendItem(name: "Taco")]
        self.friendsArray += [FriendItem(name: "Burrito")]
        self.friendsArray += [FriendItem(name: "Sweet Tea")]
        self.friendsArray += [FriendItem(name: "Boba")]
        self.tableView.reloadData()
        
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        peripheralManager?.stopAdvertising()
        print("stop advertising")
    }
    
    
    
  /*  func readSet (index:Int)->Set<String>.Element
    {
        return selected[selected.startIndex.advancedBy(index)]
    }
    
    func setCount (subtract:Int) ->Int
    {
        return selected.count-subtract
    }
    */
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        self.tableView.reloadData()
        print(selected.count)
    }
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, withEvent: event)
    }
    // MARK: - Table View
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        if peripheral.state != CBPeripheralManagerState.PoweredOn {
            return
        }
        
        print ("self.peripheralManager powered on.")
        
        transferCharacteristic = CBMutableCharacteristic(
            type: transferCharacteristicUUID_1,
            properties: CBCharacteristicProperties.Notify,
            value: nil,
            permissions: CBAttributePermissions.Readable
        )
        
        let transferService = CBMutableService(type: transferServiceUUID_1, primary: true)
        
        transferService.characteristics = [transferCharacteristic!]
        peripheralManager!.addService(transferService)
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic")
    
        var send:String = ""
        for element in selected {
            send += element + "\n"
            print("packing")
        }
        print(send)
        
        dataToSend = send.dataUsingEncoding(NSUTF8StringEncoding)
        
        
        
        // Reset the index
        sendDataIndex = 0;
        
        // Start sending
        sendData()
    }

    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
    }
    
    private var sendingEOM = false;
    
    private func sendData() {
        if sendingEOM {
            // send it
            let didSend = peripheralManager?.updateValue(
                "EOM".dataUsingEncoding(NSUTF8StringEncoding)!,
                forCharacteristic: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // Did it send?
            if (didSend == true) {
                
                // It did, so mark it as sent
                sendingEOM = false
                
                print("Sent: EOM")
            }
            
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        guard sendDataIndex < dataToSend?.length else {
            // No data left.  Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        
        while didSend {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = dataToSend!.length - sendDataIndex!;
            
            // Can't be longer than 20 bytes
            if (amountToSend > NOTIFY_MTU) {
                amountToSend = NOTIFY_MTU;
            }
            
            // Copy out the data we want
            let chunk = NSData(
                bytes: dataToSend!.bytes + sendDataIndex!,
                length: amountToSend
            )
            
            // Send it
            didSend = peripheralManager!.updateValue(
                chunk,
                forCharacteristic: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // If it didn't work, drop out and wait for the callback
            if (!didSend) {
                return
            }
            
            let stringFromData = NSString(
                data: chunk,
                encoding: NSUTF8StringEncoding
            )
            
            print("Sent: \(stringFromData)")
            
            // It did send, so update our index
            sendDataIndex! += amountToSend;
            
            // Was it the last one?
            if (sendDataIndex! >= dataToSend!.length) {
                
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                sendingEOM = true
                
                // Send it
                let eomSent = peripheralManager!.updateValue(
                    "EOM".dataUsingEncoding(NSUTF8StringEncoding)!,
                    forCharacteristic: transferCharacteristic!,
                    onSubscribedCentrals: nil
                )
                
                if (eomSent) {
                    // It sent, we're all done
                    sendingEOM = false
                    print("Sent: EOM")
                }
                
                return
            }
        }
    }

    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
    
    
    

//    @IBAction func SendButton(sender: AnyObject) {
//        peripheralManager!.startAdvertising([
//            CBAdvertisementDataServiceUUIDsKey : [transferServiceUUID_1]
//            ])
//
//    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        print(error)
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
       
        if !touched {
             if (tableView == self.searchDisplayController?.searchResultsTableView)
        {
            return self.filteredFriends.count
        }
        else
        {
            return self.friendsArray.count
        }
        }
        else
        {
         
           return selected.count
            
        }
           }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier("cell")! as UITableViewCell
        
        var friend : FriendItem
        if !touched {
            if (tableView == self.searchDisplayController?.searchResultsTableView)
        {
            friend = self.filteredFriends[indexPath.row]
            
        }
        else
        {
            friend = self.friendsArray[indexPath.row]
        }

        }
        else
        {
            friend = FriendItem(name: selected[selected.startIndex.advancedBy(indexPath.row)])
        }
                
        cell.textLabel?.text = friend.name
        
        if selected.contains(friend.name) {
            
            self.tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: .Top)
            
            
            print(selected.count)
        }
        
        
        return cell
        
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        
        
        var friend : FriendItem
        
        
        if (tableView == self.searchDisplayController?.searchResultsTableView)
        {
            friend = self.filteredFriends[indexPath.row]
            
            if !selected.contains(friend.name) {
                
                selected.insert(friend.name)            }
            
            
            
        }
        else
        {
            friend = self.friendsArray[indexPath.row]
            if !selected.contains(friend.name)
            {
                selected.insert(friend.name)
            }
            
        }
        
        print(friend.name)
        
        
    }
    
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.cellForRowAtIndexPath(indexPath)?.accessoryType = UITableViewCellAccessoryType.None
        
        var friend : FriendItem
        
        
        if (tableView == self.searchDisplayController?.searchResultsTableView)
        {
            friend = self.filteredFriends[indexPath.row]
            
            if selected.contains(friend.name) {
                
                selected.remove(friend.name)            }
            
            
            
        }
        else
        {
            friend = self.friendsArray[indexPath.row]
            if selected.contains(friend.name)
            {
                selected.remove(friend.name)
            }
            
        }

    }
    
    // MARK: - Search Methods
    
    func filterContenctsForSearchText(searchText: String, scope: String = "Title")
    {
        
        self.filteredFriends = self.friendsArray.filter({( friend : FriendItem) -> Bool in
            
            let categoryMatch = (scope == "Title")
            let stringMatch = friend.name.rangeOfString(searchText)
            
            return categoryMatch && (stringMatch != nil)
            
        })
        
        
    }
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String?) -> Bool
    {
        
        self.filterContenctsForSearchText(searchString!, scope: "Title")
        
        return true
        
        
    }
    
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchScope searchOption: Int) -> Bool
    {
        
        self.filterContenctsForSearchText(self.searchDisplayController!.searchBar.text!, scope: "Title")
        
        return true
        
    }
    
}


