//
//  DriverAnnotation.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 5/9/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import Foundation
import MapKit

class DriverAnnotation: NSObject, MKAnnotation {

    dynamic var coordinate: CLLocationCoordinate2D
    var key: String

    init(coordinate: CLLocationCoordinate2D, withKey key: String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }

    func update(annotationPosition annotation: DriverAnnotation, withCoordinate coordinate: CLLocationCoordinate2D) {
        var location = self.coordinate
        location.latitude = coordinate.latitude
        location.longitude = coordinate.longitude
        UIView.animate(withDuration: 0.2) {
            self.coordinate = location
        }
    }
}
