//
//  NORHKViewController.swift
//  nRF Toolbox
//
//  Created by Mostafa Berg on 06/03/2017.
//  Copyright © 2017 Nordic Semiconductor. All rights reserved.
//

import UIKit
import CoreBluetooth
import HomeKit

public let homeKitScannerSegue = "show_hk_scanner_view"

class NORHKViewController: NORBaseViewController, HMHomeDelegate, NORHKScannerDelegate, UITableViewDataSource, UITableViewDelegate {

    //MARK: - Properties
    private var accessoryBrowser: HMAccessoryBrowser?
    private var homeAccessories = [HMAccessory]()
    private var currentAccessory: HMAccessory?
    private var homeStore: NORHKHomeStore!

    //MARK: - Outlets and actions
    @IBOutlet weak var verticalLabel: UILabel!
    @IBOutlet weak var connectionButton: UIButton!
    @IBOutlet weak var homeTitle: UILabel!
    @IBOutlet weak var accessoryTableView: UITableView!

    @IBAction func aboutButtonTapped(_ sender: Any) {
        self.showAbout(message: NORAppUtilities.getHelpTextForService(service: .homekit))
    }

    @IBAction func connectionButtonTapped(_ sender: Any) {
            self.performSegue(withIdentifier: homeKitScannerSegue, sender: nil)
    }

    //MARK: - Implementation
    func getAccessoriesForHome(aHome: HMHome) -> [HMAccessory] {
        return aHome.accessories
    }

    func getPrimaryHome() -> HMHome? {
        return homeStore.homeManager.primaryHome
    }

    func createPrimaryHome() {
        homeStore.homeManager.addHome(withName: "MyHome") { (aHome, anError) in
            if anError == nil {
                self.homeStore.homeManager.updatePrimaryHome(aHome!, completionHandler: { (anError) in
                    if anError == nil {
                        print("Primary home upadted")
                    } else {
                        print("Errow hile updating primary home! \(anError)")
                    }
                })
                self.updateUIForHome(aHome: aHome!)
            } else {
                print("Error, home not created: \(anError!)")
            }
        }
    }
    
    func updateUIForHome(aHome: HMHome) {
        homeTitle.text = aHome.name.uppercased()
        homeAccessories = getAccessoriesForHome(aHome: aHome)
        accessoryTableView.reloadData()
    }

    func pair(anAccessory: HMAccessory, withHome aHome: HMHome) {
        print(aHome, anAccessory)
        aHome.addAccessory(anAccessory) { (error) in
            if error != nil {
                print ("Error in adding accessory \(error)")
            } else {
                NSLog("Accessory is added successfully, attemting to add to main room")
            }
            
            //Browser needs to be released after adding accessory to the home.
            //Releasing the browser before adding the accessory will result in a HomeKit error 2 (Object not found.)
            //as the selected HMAccessory object becomes invalid.
            self.accessoryBrowser?.stopSearchingForNewAccessories()
            self.accessoryBrowser = nil
        }
    }
    //MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        homeStore = NORHKHomeStore.sharedHomeStore

        verticalLabel.transform = CGAffineTransform(translationX: -(verticalLabel.frame.width/2) + (verticalLabel.frame.height / 2), y: 0.0).rotated(by: (CGFloat)(-M_PI_2))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if homeStore.homeManager.primaryHome != nil {
            homeStore.home = homeStore.homeManager.primaryHome
            updateUIForHome(aHome: homeStore.home!)
        } else {
            createPrimaryHome()
        }
    }

    //MARK: - UITableViewDataSoruce
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let aCell = tableView.dequeueReusableCell(withIdentifier: "HKAccessoryCell")
        aCell?.textLabel?.text = homeAccessories[indexPath.row].name
        if #available(iOS 9.0, *) {
            aCell?.detailTextLabel?.text = homeAccessories[indexPath.row].category.localizedDescription
        } else {
            aCell?.detailTextLabel?.text = ""
        }
        return aCell!
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return homeAccessories.count
    }

    //MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        print(homeAccessories[indexPath.row].name)
    }

    //MARK: - NORHKScannerDelegate
    func browser(aBrowser: HMAccessoryBrowser, didSelectAccessory anAccessory: HMAccessory) {
        self.accessoryBrowser = aBrowser
        self.currentAccessory = anAccessory
        self.accessoryBrowser?.delegate = nil
        self.pair(anAccessory: anAccessory, withHome: homeStore.homeManager.primaryHome!)
    }

    //MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == homeKitScannerSegue {
            let navigationController = segue.destination as? UINavigationController
            let scannerView = navigationController?.topViewController as? NORHKScannerViewController
            scannerView?.delegate = self
        }
    }
}
