import UIKit
import MapKit
import CoreLocation

// LocationInfo 구조체 정의
struct LocationInfo: Codable {
    let poiId: String
    let poiNm: String
    let gpsX: String
    let gpsY: String
    let posX: String
    let posY: String
}

// PathInfo 구조체 정의
struct PathInfo: Codable {
    let routeNm: String
    let routeId: String?
    let fname: String
    let time: String
    let tname: String
}

// ServiceResult 구조체 정의
struct ServiceResult: Codable {
    let comMsgHeader: ComMsgHeader
    let msgHeader: MsgHeader
    let msgBody: MsgBody

    struct ComMsgHeader: Codable {
        let errMsg: String?
        let responseTime: String?
        let responseMsgID: String?
        let requestMsgID: String?
        let returnCode: String?
        let successYN: String?
    }

    struct MsgHeader: Codable {
        let headerMsg: String
        let headerCd: String
        let itemCount: Int
    }

    struct MsgBody: Codable {
        let itemList: [LocationInfo]?

        enum CodingKeys: String, CodingKey {
            case itemList = "itemList"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            itemList = try? container.decodeIfPresent([LocationInfo].self, forKey: .itemList)
        }
    }
}

// PathInfoResult 구조체 정의
struct PathInfoResult: Codable {
    let comMsgHeader: ComMsgHeader
    let msgHeader: MsgHeader
    let msgBody: MsgBody

    struct ComMsgHeader: Codable {
        let errMsg: String?
        let responseTime: String?
        let responseMsgID: String?
        let requestMsgID: String?
        let returnCode: String?
        let successYN: String?
    }

    struct MsgHeader: Codable {
        let headerMsg: String
        let headerCd: String
        let itemCount: Int
    }

    struct MsgBody: Codable {
        let itemList: [PathItem]

        struct PathItem: Codable {
            let time: String
            let distance: String
            let pathList: [PathDetail]

            struct PathDetail: Codable {
                let routeNm: String
                let routeId: String?
                let fname: String
                let fx: String
                let fy: String
                let tname: String
                let tx: String
                let ty: String
            }
        }
    }
}

class SelectAddressViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var startAddressField: UITextField!
    @IBOutlet weak var endAddressField: UITextField!
    @IBOutlet weak var addressTableView: UITableView!
    @IBOutlet weak var SearchPathButton: UIButton!

    @IBOutlet weak var mapView: MKMapView!
    
    var locationData: [LocationInfo] = []
    var pathData: [PathInfo] = []
    
    var locationManager: CLLocationManager?

    // 출발지와 도착지의 좌표 저장을 위한 변수 추가
    var startLocation: (x: String, y: String)?
    var endLocation: (x: String, y: String)?
    

    override func viewDidLoad() {
           super.viewDidLoad()
           setupTableView()
           setupMapView()
           setupLocationManager()
       }

       func setupTableView() {
           addressTableView.delegate = self
           addressTableView.dataSource = self
           addressTableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
       }

       func setupMapView() {
           mapView.showsUserLocation = true
       }

       func setupLocationManager() {
           locationManager = CLLocationManager()
           locationManager?.delegate = self
           locationManager?.desiredAccuracy = kCLLocationAccuracyBest
           locationManager?.requestWhenInUseAuthorization()
           locationManager?.startUpdatingLocation()
       }

       func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
           guard let location = locations.last else { return }
           let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
           let region = MKCoordinateRegion(center: center, latitudinalMeters: 1000, longitudinalMeters: 1000)
           mapView.setRegion(region, animated: true)
       }

       func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
           print("Failed to find user's location: \(error.localizedDescription)")
       }

    func fetchData(searchText: String, completion: @escaping (Result<[LocationInfo], Error>) -> Void) {
        let baseUrl = "http://ws.bus.go.kr/api/rest/pathinfo/getLocationInfo"
        let serviceKey = "OTJNfOLNtgympz166wsmHQchtxslFQavNyHTZfy5t6bhKv0ik99yfsPrBK%2Fq%2FKL7sJ1S%2FQMSMqJeAQPwHHy%2BCQ%3D%3D"
        let encodedSearchText = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseUrl)?ServiceKey=\(serviceKey)&stSrch=\(encodedSearchText)&resultType=json"

        print("URL String: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("No data received")
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }

            do {
                let responseString = String(data: data, encoding: .utf8)
                print("Response Data: \(responseString ?? "No Data")")

                let response = try JSONDecoder().decode(ServiceResult.self, from: data)
                if let itemList = response.msgBody.itemList {
                    print("Item List Count: \(itemList.count)")
                    completion(.success(itemList))
                } else {
                    print("Item List is nil")
                    completion(.success([]))
                }
            } catch {
                print("Decoding Error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    func fetchPathInfo(startX: String, startY: String, endX: String, endY: String) {
        let baseUrl = "http://ws.bus.go.kr/api/rest/pathinfo/getPathInfoByBusNSub"
        let serviceKey = "OTJNfOLNtgympz166wsmHQchtxslFQavNyHTZfy5t6bhKv0ik99yfsPrBK%2Fq%2FKL7sJ1S%2FQMSMqJeAQPwHHy%2BCQ%3D%3D"
        let urlString = "\(baseUrl)?ServiceKey=\(serviceKey)&startX=\(startX)&startY=\(startY)&endX=\(endX)&endY=\(endY)&resultType=json"

        print("Path URL String: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                let responseString = String(data: data, encoding: .utf8)
                print("Response Data: \(responseString ?? "No Data")")

                let response = try JSONDecoder().decode(PathInfoResult.self, from: data)
                self.pathData = response.msgBody.itemList.flatMap { item in
                    item.pathList.map { detail in
                        PathInfo(routeNm: detail.routeNm, routeId: detail.routeId, fname: detail.fname, time: item.time, tname: detail.tname)
                    }
                }
                DispatchQueue.main.async {
                    self.addressTableView.reloadData()
                }
            } catch {
                print("Decoding Error: \(error.localizedDescription)")
            }
        }

        task.resume()
    }

    @IBAction func startAddressButtonTapped(_ sender: Any) {
        guard let searchText = startAddressField.text, !searchText.isEmpty else {
            return
        }
        fetchData(searchText: searchText) { result in
            switch result {
            case .success(let data):
                self.locationData = data
                DispatchQueue.main.async {
                    self.addressTableView.reloadData()
                }
            case .failure(let error):
                print("Error fetching data: \(error)")
            }
        }
    }

    @IBAction func endAddressButtonTapped(_ sender: Any) {
        guard let searchText = endAddressField.text, !searchText.isEmpty else {
            return
        }
        fetchData(searchText: searchText) { result in
            switch result {
            case .success(let data):
                self.locationData = data
                DispatchQueue.main.async {
                    self.addressTableView.reloadData()
                }
            case .failure(let error):
                print("Error fetching data: \(error)")
            }
        }
    }

    @IBAction func searchPathButtonTapped(_ sender: UIButton) {
        guard let startLocation = startLocation, let endLocation = endLocation else {
            print("Start or end location is missing")
            return
        }
        fetchPathInfo(startX: startLocation.x, startY: startLocation.y, endX: endLocation.x, endY: endLocation.y)
    }
}

extension SelectAddressViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = pathData.isEmpty ? locationData.count : pathData.count
        mapView.isHidden = count > 0
        addressTableView.isHidden = count == 0
        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        if pathData.isEmpty {
            let location = locationData[indexPath.row]
            cell.textLabel?.text = location.poiNm
        } else {
            let path = pathData[indexPath.row]
            let attributedString = NSMutableAttributedString()
            let timeString = NSAttributedString(string: "  \(path.time)분\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18)])
            let routeString = NSAttributedString(string: "  \(path.fname) - \(path.tname)\n", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            let routeNmString = NSAttributedString(string: "  버스 \(path.routeNm)번", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)])
            
            attributedString.append(timeString)
            attributedString.append(routeString)
            attributedString.append(routeNmString)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 3
            attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))

            cell.textLabel?.numberOfLines = 0 // 여러 줄 표시 가능하도록 설정
            cell.textLabel?.attributedText = attributedString
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if pathData.isEmpty {
            let selectedLocation = locationData[indexPath.row]
            if startAddressField.isFirstResponder {
                startLocation = (selectedLocation.gpsX, selectedLocation.gpsY)
                startAddressField.text = selectedLocation.poiNm
            } else if endAddressField.isFirstResponder {
                endLocation = (selectedLocation.gpsX, selectedLocation.gpsY)
                endAddressField.text = selectedLocation.poiNm
            }
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
