import UIKit

class DeviceCell: UITableViewCell {
    
    @IBOutlet weak var deviceImage: UIImageView!
    @IBOutlet weak var deviceName: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
