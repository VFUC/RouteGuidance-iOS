//
//  NextBusStopViewController.swift
//  FöliGuide
//
//  Created by Jonas on 01/02/16.
//  Copyright © 2016 Capstone Innovation Project - Route Guidance. All rights reserved.
//

import UIKit

class NextBusStopViewController: UIViewController {

	@IBOutlet weak var busNumberLabel: UILabel!
	@IBOutlet weak var nextStationNameLabel: UILabel!
	@IBOutlet weak var afterThatStationNameLabel: UILabel!
	@IBOutlet weak var finalStationName: UILabel!
	@IBOutlet weak var selectedBusStationNameLabel: UILabel!
	@IBOutlet weak var selectedBusStationStackView: UIStackView!
	@IBOutlet weak var mainStackView: UIStackView!
	@IBOutlet weak var alarmBarButton: UIBarButtonItem!
	
	let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
	
	var alarmSet = false {
		didSet {
			if alarmSet {
				mainStackView.addArrangedSubview(selectedBusStationStackView)
				alarmBarButton.image = UIImage(named: Constants.Assets.Images.AlarmBarButton.Filled)
				appDelegate.alarmIsSet = true
			} else {
				mainStackView.removeArrangedSubview(selectedBusStationStackView)
				alarmBarButton.image = UIImage(named: Constants.Assets.Images.AlarmBarButton.Outline)
				appDelegate.alarmIsSet = false
			}
		}
	}
	
	var destinationStop : String? {
		didSet {
			alarmSet = !(destinationStop == nil)
			selectedBusStationNameLabel.text = destinationStop
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		destinationStop = nil
		busNumberLabel.text = ""
		nextStationNameLabel.text = ""
		afterThatStationNameLabel.text = ""
		appDelegate.nextBusStopVC = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	
	// Data has been updated, check if notification is necessary
	func didUpdateData(){
		if nextStationNameLabel.text == destinationStop {
			NotificationController.showNextBusStationNotification(stopName: nextStationNameLabel.text!, viewController: self)
		}
	
		if afterThatStationNameLabel.text == destinationStop {
			NotificationController.showAfterThatBusStationNotification(stopName: nextStationNameLabel.text!, viewController: self)
		}
	}
	
	
	
	@IBAction func alarmButtonPressed(sender: UIBarButtonItem) {
		if alarmSet {
			
			let alertController = UIAlertController(title: "Remove Alarm?", message: "Do you want to remove the alarm for \(destinationStop ?? "--")", preferredStyle: .Alert)
			alertController.addAction(UIAlertAction(title: "Remove", style: .Destructive, handler: { _ -> Void in
				self.destinationStop = nil
			}))
			alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
			
			presentViewController(alertController, animated: true, completion: nil)
			
		} else {
			self.performSegueWithIdentifier("showDestinationSelectionVC", sender: nil)
		}
		
	}
	

	// MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
		if let vc = segue.destinationViewController as? DestinationSelectionTableViewController {
			vc.nextStopVC = self
		}
	}
	
}
