import UIKit
import SwiftSocket

class ViewController: UIViewController, MainPresenterDelegate,UITableViewDelegate,UITableViewDataSource {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var navigationBarTitle: UINavigationItem!
    @IBOutlet weak var scanButton: UIBarButtonItem!
    @IBOutlet weak var tableTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!
    //aa
    let deviceName: [String] = ["HomeLight","MainDoor","GarageDoor","Thermometer","oven","washingmachine","cctv"]
    let deviceImg = [
        UIImage(named: "light.png"),
        UIImage(named: "main.png"),
        UIImage(named: "garage.png"),
        UIImage(named: "temp.png"),
        UIImage(named: "oven.png"),
        UIImage(named: "wasingmachine.png"),
        UIImage(named: "cctv.png")
    ]
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
        
        self.appendToTextField(string: "라즈베리파이에 연결되지 않았습니다.")
        
        self.presenter = MainPresenter(delegate:self)
        
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
            if tableView.cellForRow(at: indexPath)?.accessoryType == UITableViewCell.AccessoryType.checkmark{
                tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.none
            }else{
                tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.checkmark
            }
            
            let isOn: String = tableView.cellForRow(at: indexPath)?.accessoryType == UITableViewCell.AccessoryType.checkmark ? "ON" : "OFF"
            
            guard let Reclient = Rclient else { return }
            
            switch Reclient.send(string: deviceName[indexPath.row]+isOn) {
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

        self.showAlert(title: "스캔 완료", message: "같은 AP에 연결된 기기의 수 : \(self.presenter.connectedDevices.count)")

        
        //----------서버 연결----------//
        connectServer()
        //----------서버 연결----------//
    }
    
    func connectServer(){
        if (self.presenter.connectedDevices.count != 0)
        {
            let deviceCount = self.presenter.connectedDevices.count
            for inx in 0...deviceCount - 1 {
             
                let host = self.presenter.connectedDevices[inx].ipAddress as String
             
                client = TCPClient(address: host, port: Int32(port))
                guard let client = client else { return }
             
                let StartServer = client.connect(timeout: 3)
            
                DispatchQueue.main.asyncAfter(deadline: .now() + 1){
                    if StartServer.isSuccess{
                        self.Rclient = client
                        self.appendToTextField(string: "\(client.address)에 연결 되었습니다.")
                    }
                }
            }
        }else{
            appendToTextField(string: "새로 고침 다시 해주세요")
        }
    }
    
    func mainPresenterIPSearchCancelled() {

        self.hideProgressBar()
    }
    
    func mainPresenterIPSearchFailed() {
        
        self.hideProgressBar()
        self.showAlert(title: "스캔이 실패하였습니다.", message: "와이파이에 제대로 연결 되어 있는지 확인 하세요")
    }
    
    func showAlert(title:String, message: String) {
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in}
        
        alertController.addAction(okAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    func showErrorAlert() {
        
        let alertController = UIAlertController(title: "에러", message: "서버에 연결되지 않았습니다.", preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in}
        
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
                print("유효하지 않은 키")
            }
        }
    }
    
    deinit {
        self.removeObserversForKVO()
    }
//--------------------------------------같은 AP상의 IP주소 찾기--------------------------------------//
    
//--------------------------------------데이터 전송--------------------------------------//

    
    private func appendToTextField(string: String) {
        navigationBarTitle.title = string
    }
}
