//
//  Bus.swift
//  FöliGuide
//
//  Created by Jonas on 27/01/16.
//  Copyright © 2016 Capstone Innovation Project - Route Guidance. All rights reserved.
//

import UIKit
import CoreLocation

struct Bus {
	var vehicleRef: String
	var blockRef: String
	var location: CLLocation
	var name: String //name == "Bus number"
	var nextStop: BusStop
	var afterThatStop: BusStop?
	var finalStop: String
	var distanceToUser: CLLocationDistance?
	var route: [BusStop]?
}
