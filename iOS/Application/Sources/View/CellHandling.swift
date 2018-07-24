import UIKit

public protocol CellDequeuing {
  func dequeueReusableCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType
}

extension UITableView: CellDequeuing {
  public func dequeueReusableCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType {
    let identifier = String(describing: CellType.self)
    guard let cell = self.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? CellType else {
      preconditionFailure("cell with identifier \(identifier) is not of type \(CellType.self)")
    }
    return cell
  }
}
