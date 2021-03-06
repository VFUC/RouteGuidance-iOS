//
//  BusDataController.swift
//  FöliGuide
//
//  Created by Jonas on 27/01/16.
//  Copyright © 2016 Capstone Innovation Project - Route Guidance. All rights reserved.
//

import UIKit
import CoreLocation
import SwiftyJSON
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}



// Used to pass parameters to the bus data retrieval loop
class BusLoopParameters {
    var completionHandler: ([Bus]?) -> Void

    init(completionHandler: (@escaping ([Bus]?) -> Void)) {
        self.completionHandler = completionHandler
    }
}


class BusDataController: NSObject {

    fileprivate var timer: Timer? // used for running network loop
    var currentUserBus: Bus? // current bus the user has selected
    var currentBusData: [Bus]? // last saved bus data


    fileprivate func getCurrentBusData(_ completionHandler: @escaping ([Bus]?) -> Void ) {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.callNetworkEvent(.busLoadingStarted)


        NetworkController.getBusData { (json) -> Void in

            guard let json = json else {
                appDelegate?.callNetworkEvent(.loadingFailed)
                completionHandler(nil)
                return
            }

            guard let vehicles = json["result"]["vehicles"].dictionary else {
                completionHandler(nil)
                return
            }

            var busses = [Bus]()

            for (_, vehicle) in vehicles {
                if let name = vehicle["lineref"].string,
                    let longitude = vehicle["longitude"].float,
                    let blockRef = vehicle["blockref"].string,
                    let latitude = vehicle["latitude"].float,
                    let nextStopNumber = vehicle["next_stoppointref"].string,
                    let nextStopName = vehicle["next_stoppointname"].string,
                    let vehicleRef = vehicle["vehicleref"].string,
                    let finalStop = vehicle["destinationname"].string {


                    var expectedArrivalDate: Date?
                    if let expectedArrival = vehicle["next_expectedarrivaltime"].float {
                        expectedArrivalDate = Date(timeIntervalSince1970: TimeInterval(expectedArrival))
                    }

                    let nextStop = BusStop(name: nextStopName, number: nextStopNumber, location: nil, expectedArrival: expectedArrivalDate)
                    var afterThatStop: BusStop?

                    if let onwardCalls = vehicle["onwardcalls"].array, onwardCalls.count > 0 {
                        if let name = onwardCalls[0]["stoppointname"].string,
                            let number = onwardCalls[0]["visitnumber"].int {
                            afterThatStop = BusStop(name: name, number: "\(number)", location: nil, expectedArrival: nil)
                        }
                    }


                    let bus = Bus(vehicleRef: vehicleRef, blockRef: blockRef, location: CLLocation(latitude: CLLocationDegrees(latitude), longitude: CLLocationDegrees(longitude)), name: name, nextStop: nextStop, afterThatStop: afterThatStop, finalStop: finalStop, distanceToUser: nil, route: nil)
                    busses.append(bus)
                }
            }

            self.currentBusData = busses

            appDelegate?.callNetworkEvent(.busLoadingFinished)
            completionHandler(busses)
        }
    }

    // Gets the current bus stop data
    func getBusStops(completionHandler: @escaping ([BusStop]?) -> Void) {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.callNetworkEvent(.busStopLoadingStarted)
        NetworkController.getBusStopData { (json) -> Void in
            guard let json = json else {
                appDelegate?.callNetworkEvent(.loadingFailed)
                completionHandler(nil)
                return
            }

            guard let dict = json.dictionary else {
                completionHandler(nil)
                return
            }

            var stops = [BusStop]()


            for (key, value) in dict { //key: station number, value: dict{ "stop_name": name }
                if let name = value["stop_name"].string {
                    stops.append(BusStop(name: name, number: key, location: nil, expectedArrival: nil))
                }
            }

            appDelegate?.callNetworkEvent(.busStopLoadingFinished)
            completionHandler(stops)
        }
    }

    func getBusRoute(forBus bus: Bus, completionHandler: @escaping ([BusStop]?) -> Void) {
        NetworkController.getRoutesData { (json) -> Void in
            guard let json = json else {
                completionHandler(nil)
                return
            }

            guard let routes = json.array else {
                completionHandler(nil)
                return
            }

            var matchingRouteID: String?

            for route in routes {
                if let dictionary = route.dictionary,
                    let routeID = dictionary["route_id"]?.string,
                    let shortName = dictionary["route_short_name"]?.string, shortName == bus.name {
                    matchingRouteID = routeID
                    break
                }
            }

            guard let routeID = matchingRouteID else {
                print("[BusDataController] No routeID found for bus \(bus.name)")
                completionHandler(nil)
                return
            }

            NetworkController.getTripsData(withRouteID: routeID, completionHandler: { (json) -> Void in
                guard let json = json else {
                    completionHandler(nil)
                    return
                }

                guard let trips = json.array else {
                    completionHandler(nil)
                    return
                }

                var matchingTripID: String?
                var directionID: Int?

                for trip in trips {
                    if let dictionary = trip.dictionary,
                        let tripID = dictionary["trip_id"]?.string,
                        let dirID = dictionary["direction_id"]?.int,
                        let blockID = dictionary["block_id"]?.string, blockID == bus.blockRef {
                        matchingTripID = tripID
                        directionID = dirID
                        break
                    }
                }

                guard let tripID = matchingTripID else {
                    print("[BusDataController] No Trip found for bus \(bus.name) with route id \(routeID)")
                    completionHandler(nil)
                    return
                }

                NetworkController.getTripData(withTripID: tripID, completionHandler: { (json) -> Void in
                    guard let json = json else {
                        completionHandler(nil)
                        return
                    }

                    guard let stops = json.array else {
                        completionHandler(nil)
                        return
                    }

                    var busStopIDs = [String]()

                    for stop in stops {
                        if let dictionary = stop.dictionary,
                            let stopID = dictionary["stop_id"]?.string {
                            busStopIDs.append(stopID)
                        }
                    }

                    //Reverse stops if directionID implies so
                    if directionID == 0 {
                        busStopIDs = busStopIDs.reversed()
                    }

                    self.getBusStops(fromIDs: busStopIDs, completionHandler: completionHandler)
                })

            })

        }
    }



    func getBusStops(fromIDs ids: [String], completionHandler: @escaping ([BusStop]?) -> Void) {

        NetworkController.getBusStopData { (json) -> Void in
            guard let json = json else {
                completionHandler(nil)
                return
            }

            guard let dict = json.dictionary else {
                completionHandler(nil)
                return
            }

            var stops = [BusStop]()

            for id in ids {
                //look for name in dict
                if let name = dict[id]?["stop_name"].string {
                    stops.append(BusStop(name: name, number: id, location: nil, expectedArrival: nil))
                }
            }
            completionHandler(stops)
        }
    }





    // Sets the distance to the user property on all the input busses
    fileprivate func setDistanceToUserOnBusses(_ busses: [Bus], location: CLLocation) -> [Bus] {
        var mutable = busses

        for (index, bus) in busses.enumerated() {
            mutable[index].distanceToUser = location.distance(from: bus.location)
        }

        return mutable
    }

    fileprivate func isOrderedBeforeByDistanceToUser(_ bus1: Bus, bus2: Bus) -> Bool {
        return bus1.distanceToUser < bus2.distanceToUser
    }

    // Runs loop action immediately (if timer set)
    func runNow() {
        self.timer?.fire()
    }

    // Stops the currently running loop
    func stopRunningLoop() {
        guard let timer = timer else {
            print("[BusDataController] Trying to stop a timer that has not been set anyways")
            return
        }

        timer.invalidate()
        self.timer = nil
    }


    // Periodically retrieves bus data
    func getBussesInLoop(intervalInSeconds: Double, completionHandler: @escaping ([Bus]?) -> Void) {
        guard timer == nil else {
            print("[BusDataController] Timer is set -> not starting again")
            return
        }

        let parameters = BusLoopParameters(completionHandler: completionHandler)

        timer = Timer.scheduledTimer(timeInterval: intervalInSeconds, target: self, selector: #selector(BusDataController.getBussesLoop(_:)), userInfo: parameters, repeats: true)

        timer?.fire() // start right away
    }

    func getBussesOnce(_ completionHandler: @escaping ([Bus]?) -> Void) {
        getCurrentBusData(completionHandler)
    }


    // Function used in timer loop to periodically retrieve bus data, arguments passed via BusLoopParameter struct
    @objc fileprivate func getBussesLoop(_ timer: Timer) {
        guard let parameters = timer.userInfo as? BusLoopParameters else {
            print("[BusDataController] Sending parameter of unrecognized type to busLoop")
            return
        }

        NetworkController.cancelActiveBusDataRequest() // in case a request is still running

        getCurrentBusData(parameters.completionHandler)
    }





    // Returns input bus array, sorted by distance to user
    func sortBussesByDistanceToUser(busses: [Bus], userLocation: CLLocation) -> [Bus] {
        let bussesWithDistance = setDistanceToUserOnBusses(busses, location: userLocation)

        let sorted = bussesWithDistance.sorted(by: self.isOrderedBeforeByDistanceToUser)

        return Array(sorted)
    }

    // Returns array of bus stop names, based on input busstops, checked against blacklist and filtered out duplicates (next to each other)
    class func namesForBusStops(_ stops: [BusStop], preserveOrder: Bool) -> [String] {
        if preserveOrder {
            var names = [String]()
            for stop in stops {
                if Constants.BusStopNameBlacklist.contains(stop.name) {
                    continue
                }
                names.append(stop.name)
            }

            for (index, name) in names.enumerated() {
                if index < names.count - 1 && names[index + 1] == name {
                    names.remove(at: index)
                }
            }

            return names

        } else {
            var names = Set<String>()

            for stop in stops {
                names.insert(stop.name)
            }

            return Array(names)
        }
    }


}
