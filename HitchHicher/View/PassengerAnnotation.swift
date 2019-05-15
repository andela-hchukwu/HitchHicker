//
//  PassengerAnnotation.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 5/15/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import Foundation
import MapKit

class PassengerAnnotation: NSObject, MKAnnotation {

    dynamic var coordinate: CLLocationCoordinate2D
    var key: String

    init(coordinate: CLLocationCoordinate2D, key:String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }
}
