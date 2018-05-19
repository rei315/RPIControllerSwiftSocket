import UIKit
import SwiftSocket

class ViewController: UIViewController, MainPresenterDelegate,UITableViewDelegate,UITableViewDataSource {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var navigationBarTitle: UINavigationItem!
    @IBOutlet weak var scanButton: UIBarButtonItem!
    @IBOutlet weak var tableTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!
    
    var deviceName: [String] = ["HomeLight","MainDoor","GarageDoor","Thermometer","oven","washingmachine","cctv","macbook"]
    var deviceImg: [UIImage] = [#imageLiteral(resourceName: "light"),#imageLiteral(resourceName: "main"),#imageLiteral(resourceName: "garage"),#imageLiteral(resourceName: "temp"),#imageLiteral(resourceName: "open"),#imageLiteral(resourceName: "wasingmachine"),#imageLiteral(resourceName: "cctv"),#imageLiteral(resourceName: "macbook")]
    
    var presenter: MainPresenter!
    private var myContext = 0
    
    let port = 34730
    var client: TCPClient?
    var Rclient: TCPClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.progressView.alpha = 0.0
        self.tableView.backgroundColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1.0)
        //presenter 생성
        self.presenter = MainPresenter(delegate:self)
        
        //presenter 값을 모니터링하기 위해 observer을 추가함
        //바뀌는 이 값들이 MainVC UI 이 수정 될 것임
        //즉 쉽게 말해 바뀌는 이 값들을 실시간으로 모니터링 하여 특정 값에 해당하는 실행을 함
        self.addObserversForKVO()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return deviceName.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Device", for: indexPath) as! DeviceCell
        
        cell.deviceImage.image = deviceImg[indexPath.row]
        cell.deviceName.text = deviceName[indexPath.row]

        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (Rclient != nil){
            if tableView.cellForRow(at: indexPath)?.accessoryType == UITableViewCellAccessoryType.checkmark{
                tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCellAccessoryType.none
            }else{
                tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCellAccessoryType.checkmark
            }
            
            guard let Reclient = Rclient else { return }
            
            switch Reclient.send(string: deviceName[indexPath.row] ) {
            case .success:
                guard let data = Reclient.read(1024*10) else { return }
                
                if let response = String(bytes: data, encoding: .utf8) {
                    print(response)
                }
            case .failure(let error):
                print(error)
            }
        }else{
            showErrorAlert()
        }
    }

//--------------------------------------같은 AP상의 IP주소 찾기--------------------------------------//

    @IBAction func refresh(_ sender: Any) {
        self.showProgressBar()
        self.presenter.scanButtonClicked()
    }
    
//--------------------------------------옵저버--------------------------------------//
    //MARK: - KVO Observers
    func addObserversForKVO ()->Void {
        
        self.presenter.addObserver(self, forKeyPath: "connectedDevices", options: .new, context:&myContext)
        self.presenter.addObserver(self, forKeyPath: "progressValue", options: .new, context:&myContext)
        self.presenter.addObserver(self, forKeyPath: "isScanRunning", options: .new, context:&myContext)
    }
    
    func removeObserversForKVO ()->Void {
        
        self.presenter.removeObserver(self, forKeyPath: "connectedDevices")
        self.presenter.removeObserver(self, forKeyPath: "progressValue")
        self.presenter.removeObserver(self, forKeyPath: "isScanRunning")
    }
//--------------------------------------옵저버--------------------------------------//
    
    //MARK: - Show/Hide Progress Bar
    func showProgressBar()->Void {
        
        self.progressView.progress = 0
        UIView.animate(withDuration: 0.3) { () -> Void in
            self.progressView.alpha = 1.0
        }
        UIView.animate(withDuration: 0.5, animations: {
            self.tableTopConstraint.constant = 30
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func hideProgressBar()->Void {
        self.progressView.alpha = 0.0
        UIView.animate(withDuration: 0.5, animations: {
            
            self.tableTopConstraint.constant = 0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func mainPresenterIPSearchFinished() {
        
        self.hideProgressBar()

        self.showAlert(title: "Scan Finished", message: "Number of devices connected to the Local Area Network : \(self.presenter.connectedDevices.count)")
        
        /*
        //textField에 검색된 ip주소들 나타내기
        let deviceCount = self.presenter.connectedDevices.count
        for inx in 0...deviceCount-1 {
            ipinfo.text = ipinfo.text.appending("\n\(self.presenter.connectedDevices[inx].ipAddress as String)")
        }
        */
        //----------서버 연결----------//
        connectServer()
        //----------서버 연결----------//
    }
    
    func connectServer(){
        if (self.presenter.connectedDevices.count != 0)
        {
            
            
             //--------------------------------------실제 코드--------------------------------------//
             let deviceCount = self.presenter.connectedDevices.count
             for inx in 0...deviceCount-1 {
             
             let host = self.presenter.connectedDevices[inx].ipAddress as String
             
             client = TCPClient(address: host, port: Int32(port))
             guard let client = client else { return }
             
             let StartServer = client.connect(timeout: 5)
             if StartServer.isSuccess{
             Rclient = client
             appendToTextField(string: "\(client.address)에 연결 되었습니다.")
             }else{
             appendToTextField(string: "라즈베리파이가 검색 되지 않습니다.")
             }
             
             }
             //--------------------------------------실제 코드--------------------------------------//
             
            
            /*
            //--------------------------------------Test--------------------------------------//
            let host = "127.0.0.1" //test 용
            
            client = TCPClient(address: host, port: Int32(port))
            guard let client = client else { return }
            
            let StartServer = client.connect(timeout: 5)
            if StartServer.isSuccess{
                Rclient = client
                appendToTextField(string: "\(client.address)에 연결 되었습니다.")
            }else{
                appendToTextField(string: "라즈베리파이가 검색 되지 않습니다.")
            }
            //--------------------------------------Test--------------------------------------//
            */
        }else{
            appendToTextField(string: "새로 고침 다시 해주세요")
        }
    }
    
    func mainPresenterIPSearchCancelled() {

        self.hideProgressBar()
    }
    
    func mainPresenterIPSearchFailed() {
        
        self.hideProgressBar()
        self.showAlert(title: "Failed to scan", message: "Please make sure that you are connected to a WiFi before starting LAN Scan")
    }
    
    func showAlert(title:String, message: String) {
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in}
        
        alertController.addAction(okAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    func showErrorAlert() {
        
        let alertController = UIAlertController(title: "에러", message: "서버에 연결되지 않았습니다.", preferredStyle: UIAlertControllerStyle.alert)
        
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in}
        
        alertController.addAction(okAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if (context == &myContext) {
            
            switch keyPath! {
            case "connectedDevices":
                print("connected")
            case "progressValue":
                self.progressView.progress = self.presenter.progressValue
            case "isScanRunning":
                let isScanRunning = change?[.newKey] as! BooleanLiteralType
                self.scanButton.image = isScanRunning ? #imageLiteral(resourceName: "stop") : #imageLiteral(resourceName: "refresh")
            default:
                print("Not valid key for observing")
            }
        }
    }
    
    deinit {
        self.removeObserversForKVO()
    }
//--------------------------------------같은 AP상의 IP주소 찾기--------------------------------------//
    
//--------------------------------------데이터 전송--------------------------------------//

    
    private func appendToTextField(string: String) {
        print(string)
        navigationBarTitle.title = string
    }
}
