import UIKit

public protocol CellRegistering {
  func registerNibCell<CellType: UITableViewCell>(_ cellType: CellType.Type, bundle: Bundle?)
}

extension UITableView: CellRegistering {
  public func registerNibCell<CellType: UITableViewCell>(_ cellType: CellType.Type, bundle: Bundle?) {
    let identifier = String(describing: cellType)
    register(UINib(nibName: identifier, bundle: bundle), forCellReuseIdentifier: identifier)
  }
}

public protocol CellDequeuing {
  func dequeueReusableCell<CellType: UITableViewCell>(_ cellType: CellType.Type) -> CellType
}

extension UITableView: CellDequeuing {
  public func dequeueReusableCell<CellType: UITableViewCell>(_ cellType: CellType.Type) -> CellType {
    let identifier = String(describing: cellType)
    guard let cell = self.dequeueReusableCell(withIdentifier: identifier) as? CellType else {
      preconditionFailure("cell with identifier \(identifier) is not of type \(CellType.self)")
    }
    return cell
  }
}
