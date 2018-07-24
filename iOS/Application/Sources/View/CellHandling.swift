import UIKit

public protocol TableViewCellDequeuing {
  func dequeueReusableCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType
}

extension UITableView: TableViewCellDequeuing {
  public func dequeueReusableCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType {
    let identifier = String(describing: CellType.self)
    guard let cell = self.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? CellType else {
      preconditionFailure("cell with identifier \(identifier) is not of type \(CellType.self)")
    }
    return cell
  }
}

public protocol CollectionViewCellDequeuing {
  func dequeueReusableCell<CellType: UICollectionViewCell>(for indexPath: IndexPath) -> CellType
}

extension UICollectionView: CollectionViewCellDequeuing {
  public func dequeueReusableCell<CellType: UICollectionViewCell>(for indexPath: IndexPath) -> CellType {
    let identifier = String(describing: CellType.self)
    guard let cell = self.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? CellType else {
      preconditionFailure("cell with identifier \(identifier) is not of type \(CellType.self)")
    }
    return cell
  }
}
