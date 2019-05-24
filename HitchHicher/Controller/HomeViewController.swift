//
//  HomeViewController.swift
//  HitchHicher
//
//  Created by Henry Chukwu on 4/23/19.
//  Copyright © 2019 Henry Chukwu. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import RevealingSplashView
import  Firebase

class HomeViewController: UIViewController, Alertable {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var requestRideBtn: RoundedShadowButton!
    @IBOutlet weak var centerMapBtn: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: CircleView!
    @IBOutlet weak var cancelBtn: UIButton!

    var delegate: CenterVCDelegate?

    var manager: CLLocationManager?
    var regionRadius: CLLocationDistance = 1000

    var currentUserId: String?

    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)

    var tableView = UITableView()
    var matchingItems: [MKMapItem] = [MKMapItem]()

    var route: MKRoute!

    var selectedItemPlacemark: MKPlacemark? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        checkLocationAuthStatus()

        currentUserId = Auth.auth().currentUser?.uid

        mapView.delegate = self
        destinationTextField.delegate = self

        centerMapOnUserLocation()

        DataService.instance.REF_DRIVERS.observe(.value, with: { _ in
            self.loadDriverAnnotationsFromFB()

            DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, _) in
                if isOnTrip == true {
                    self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                }
            })
        })

        loadDriverAnnotationsFromFB()

        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()

        revealingSplashView.heartAttack = true

        UpdateService.instance.observeTrips { (tripDict) in
            if let tripDict = tripDict {
                guard let pickupCoordinateArray = tripDict["pickupCoordinate"] as? NSArray,
                    let tripKey = tripDict["passengerKey"] as? String,
                    let acceptanceStatus = tripDict["tripIsAccepted"] as? Bool
                    else { return }

                if acceptanceStatus == false {
                    DataService.instance.driverIsAvailable(key: self.currentUserId!, handler: { available in
                        if available == true {
                            let sb = UIStoryboard(name: "Main", bundle: Bundle.main)
                            guard let pickupVC = sb.instantiateViewController(withIdentifier: "PickupViewController") as? PickupViewController else { return }
                            pickupVC.initData(coordinate: CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees), passengerKey: tripKey)
                            self.present(pickupVC, animated: true, completion: nil)
                        }
                    })
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DataService.instance.REF_TRIPS.observe(.childRemoved, with: { removedTripSnapshot in
            let removedTripDict = removedTripSnapshot.value as? [String: AnyObject]
            if removedTripDict?["driverKey"] != nil {
                DataService.instance.REF_DRIVERS.child(removedTripDict?["driverKey"] as! String).updateChildValues(["driverIsOnTrip": false])
            }

            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { tripSnapshot in
                        if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                            for trip in tripSnapshot {
                                if trip.childSnapshot(forPath: "driverKey").value as? String == self.currentUserId! {
                                    let pickipCoordinateArray = trip.childSnapshot(forPath: "pickupCoordinate").value as! NSArray
                                    let pickupCoordinate = CLLocationCoordinate2D(latitude: pickipCoordinateArray[0] as! CLLocationDegrees, longitude: pickipCoordinateArray[1] as! CLLocationDegrees)
                                    let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)

                                    self.dropPinFor(placemark: pickupPlacemark)
                                    self.searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                                }
                            }
                        }
                    })

                }
            })

            DataService.instance.userIsDriver(userKey: self.currentUserId!, handler: { isDriver in
                if isDriver == true {
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                } else {
                    self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.requestRideBtn.animateButton(shouldLoad: false, withMessage: "Request ride")

                    self.destinationTextField.isUserInteractionEnabled = true
                    self.destinationTextField.text = ""

                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                    self.centerMapOnUserLocation()
                }
            })
        })

        connectUserAndDriverForTrip()
    }

    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            manager?.startUpdatingLocation()
        } else {
            manager?.requestAlwaysAuthorization()
        }
    }

    func loadDriverAnnotationsFromFB() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { snapshot in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild("userIsDriver") {
                        if driver.hasChild("coordinate") {
                            if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                                if let driverDict = driver.value as? Dictionary<String, AnyObject> {
                                    guard let coordinateArray = driverDict["coordinate"] as? NSArray else { return }
                                    let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees, longitude: coordinateArray[1] as! CLLocationDegrees)

                                    let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)

                                    var driverIsVisible: Bool {
                                        return self.mapView.annotations.contains(where: { annotation -> Bool in
                                            if let driverAnnotation = annotation as? DriverAnnotation {
                                                if driverAnnotation.key == driver.key {
                                                    driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: driverCoordinate)
                                                    return true
                                                }
                                            }
                                            return false
                                        })
                                    }

                                    if !driverIsVisible {
                                        self.mapView.addAnnotation(annotation)
                                    }
                                }
                            } else {
                                for annotation in self.mapView.annotations {
                                    if annotation.isKind(of: DriverAnnotation.self) {
                                        if let annotation = annotation as? DriverAnnotation {
                                            if annotation.key == driver.key {
                                                self.mapView.removeAnnotation(annotation)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
    }

    func connectUserAndDriverForTrip() {
        DataService.instance.userIsDriver(userKey: currentUserId!) { status in
            if status == false {
                DataService.instance.REF_TRIPS.child(self.currentUserId!).observe(.value, with: { tripSnapshot in
                    let tripDict = tripSnapshot.value as? [String: AnyObject]

                    if tripDict?["tripIsAccepted"] as? Bool == true {
                        self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)

                        let driverId = tripDict?["driverKey"] as! String
                        let pickupCoordinateArray = tripDict?["pickupCoordinate"] as! NSArray
                        let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                        let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                        let pickupMapItem = MKMapItem(placemark: pickupPlacemark)

                        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { driverSnapshot in
                            if let driverSnapshot = driverSnapshot.children.allObjects as? [DataSnapshot] {
                                for driver in driverSnapshot {
                                    if driver.key == driverId {
                                        let driverCoordinateArray = driver.childSnapshot(forPath: "coordinate").value as! NSArray
                                        let driverCoordinate = CLLocationCoordinate2D(latitude: driverCoordinateArray[0] as! CLLocationDegrees, longitude: driverCoordinateArray[1] as! CLLocationDegrees)
                                        let driverPlacemark = MKPlacemark(coordinate: driverCoordinate)
                                        let driverMapItem = MKMapItem(placemark: driverPlacemark)

                                        let passengerAnnotation = PassengerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)
//                                        let driverAnnotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driverId)

                                        self.mapView.addAnnotation(passengerAnnotation)
                                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: driverMapItem, withDestinationMapItem: pickupMapItem)
                                        self.requestRideBtn.animateButton(shouldLoad: false, withMessage: "Driver coming")
                                        self.requestRideBtn.isUserInteractionEnabled = false
                                    }
                                }
                            }
                        })
                    }
                })
            }
        }
    }

    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }

    @IBAction func cancelBtnWasPressed(_ sender: Any) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: tripKey!, forDriverKey: driverKey!)
            }
        }

        DataService.instance.passengerIsOnTrip(passengerKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: self.currentUserId!, forDriverKey: driverKey!)
            } else {
                UpdateService.instance.cancelTrip(withPassengerKey: self.currentUserId!, forDriverKey: driverKey!)
            }
        }

        self.requestRideBtn.isUserInteractionEnabled = true
    }


    @IBAction func centerMapBtnWasPressed(_ sender: Any) {

        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == self.currentUserId! {
                        if user.hasChild("tripCoordinate") {
                            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        } else {
                            self.centerMapOnUserLocation()
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        }
                    }
                }
            }
        })
    }

    @IBAction func requestRideBtnWasPressed(_ sender: Any) {
        UpdateService.instance.updateTripsWithCoordinateUponRequest()
        requestRideBtn.animateButton(shouldLoad: true, withMessage: nil)

        self.view.endEditing(true)
        destinationTextField.isUserInteractionEnabled = false
    }
    @IBAction func menuBtnWasPressed(_ sender: Any) {
        delegate?.toggleLeftPanel()
    }

}

extension HomeViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)

        DataService.instance.userIsDriver(userKey: currentUserId!) { isDriver in
            if isDriver == true {
                DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            } else {
                DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            }
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = "driver"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "driverAnnotation")

            return view
        } else if let annotation = annotation as? PassengerAnnotation {
            let identifier = "passenger"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "currentLocationAnnotation")

            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "destination")
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.image = UIImage(named: "destinationAnnotation")
            return annotationView
        }

        return nil
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRenderer = MKPolylineRenderer(overlay: self.route.polyline)
        lineRenderer.strokeColor = UIColor(red: 216 / 255, green: 71 / 255, blue: 30 / 255, alpha: 0.75)
        lineRenderer.lineWidth = 3
//        lineRenderer.lineJoin = .bevel
        shouldPresentLoadingView(false)

        return lineRenderer
    }

    func performSearch() {
        matchingItems.removeAll()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destinationTextField.text
        request.region = mapView.region

        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            if error != nil {
                self.showAlert("An error occured, please try again.")
            } else if response?.mapItems.count == 0 {
                self.showAlert("no results! Please search again for a different location")
            } else {
                if let mapItems = response?.mapItems {
                    for mapItem in mapItems {
                        self.matchingItems.append(mapItem)
                    }
                    self.tableView.reloadData()
                    self.shouldPresentLoadingView(false)
                }
            }
        }
    }

    func dropPinFor(placemark: MKPlacemark) {
        selectedItemPlacemark = placemark

        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }

        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        mapView.addAnnotation(annotation)
    }

    func searchMapKitForResultsWithPolyline(forOriginMapItem originMapItem: MKMapItem?, withDestinationMapItem destinationMapItem: MKMapItem) {
        let request = MKDirections.Request()
        if originMapItem == nil {
            request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originMapItem
        }

        request.destination = destinationMapItem
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)

        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert("An error occured Please try again.")
                return
            }
            self.route = response.routes[0]

            if self.mapView.overlays.count == 0 {
                self.mapView.addOverlay(self.route.polyline)
            }

            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)

            let delegate = AppDelegate.getAppDelegate()
            delegate.window?.rootViewController?.shouldPresentLoadingView(false)
        }
    }

    func zoom(toFitAnnotationsFromMapView mapView: MKMapView, forActiveTripWithDriver: Bool, withKey key: String?) {
        if mapView.annotations.count == 0 {
            return
        }

        var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -180)

        if forActiveTripWithDriver {
            for annotation in mapView.annotations {
                if let annotation = annotation as? DriverAnnotation {
                    if annotation.key == key {
                        topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                        topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                        bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                        bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.longitude)
                    }
                } else {
                    topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                    topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                    bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                    bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.longitude)
                }
            }
        }

        for annotation in mapView.annotations where !annotation.isKind(of: DriverAnnotation.self) {
            topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
            topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
            bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
            bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.longitude)
        }

        var region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(topLeftCoordinate.latitude - (topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 0.5, topLeftCoordinate.longitude + (bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 0.5), span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 2.0, longitudeDelta: fabs(bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 2.0))

        region = mapView.regionThatFits(region)
        mapView.setRegion(region, animated: true)
    }

    func removeOverlaysAndAnnotations(forDrivers: Bool?, forPassengers: Bool?) {
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            }

            if forPassengers! {
                if let annotation = annotation as? PassengerAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }

            if forDrivers! {
                if let annotation = annotation as? DriverAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
        }

        for overlay in mapView.overlays {
            if overlay is MKPolyline {
                mapView.removeOverlay(overlay)
            }
        }
    }
}

extension HomeViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthStatus()
        if status == .authorizedAlways {
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }

}

extension HomeViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {

        if textField == destinationTextField {
            tableView.frame = CGRect(x: 20, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 170)
            tableView.layer.cornerRadius = 5.0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "locationCell")

            tableView.delegate = self
            tableView.dataSource = self

            tableView.tag = 18
            tableView.rowHeight = 60

            view.addSubview(tableView)
            animateTableView(shouldShow: true)

            UIView.animate(withDuration: 0.2) {
                self.destinationCircle.backgroundColor = UIColor.red
                self.destinationCircle.borderColor = UIColor.init(red: 199 / 255, green: 0 / 255, blue: 0 / 255, alpha: 1.0)
            }
        }

    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == destinationTextField {
             performSearch()
            shouldPresentLoadingView(true)
            view.endEditing(true)
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            if destinationTextField.text == "" || destinationTextField.text == nil {
                UIView.animate(withDuration: 0.2) {
                    self.destinationCircle.backgroundColor = UIColor.lightGray
                    self.destinationCircle.borderColor = UIColor.darkGray
                }
            }
        }
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        matchingItems = []
        tableView.reloadData()

        DataService.instance.REF_USERS.child(currentUserId!).child("tripCoordinate").removeValue()

        mapView.removeOverlays(mapView.overlays)
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            } else if annotation.isKind(of: PassengerAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        centerMapOnUserLocation()
        return true
    }

    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2) {
                self.tableView.frame = CGRect(x: 20, y: 170, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: self.view.frame.height, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }) { (finished) in
                for subview in self.view.subviews {
                    if subview.tag == 18 {
                        subview.removeFromSuperview()
                    }
                }
            }
        }
    }
}

extension HomeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        shouldPresentLoadingView(true)

        guard let userId = currentUserId,
            let passengerCoordinate = manager?.location?.coordinate
                else { return }

        let passengerAnnotation = PassengerAnnotation(coordinate: passengerCoordinate, key: userId)
        mapView.addAnnotation(passengerAnnotation)

        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text

        let selectedMapItem = matchingItems[indexPath.row]

        DataService.instance.REF_USERS.child(userId).updateChildValues(["tripCoordinate": [selectedMapItem.placemark.coordinate.latitude, selectedMapItem.placemark.coordinate.longitude]])

        dropPinFor(placemark: selectedMapItem.placemark)

        searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: selectedMapItem)

        animateTableView(shouldShow: false)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" || destinationTextField.text == nil {
            animateTableView(shouldShow: false)
        }
    }

}

extension HomeViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")
        let mapItem = matchingItems[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title

        return cell
    }
}

