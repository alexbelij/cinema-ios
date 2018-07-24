import UIKit

public protocol TableViewDequeuing {
  func dequeueReusableCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType
  func dequeueReusableHeaderFooterView<ViewType: UITableViewHeaderFooterView>() -> ViewType
}

extension UITableView: TableViewDequeuing {
  public func dequeueReusableCell<CellType: UITableViewCell>(for indexPath: IndexPath) -> CellType {
    let identifier = String(describing: CellType.self)
    guard let cell = self.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? CellType else {
      preconditionFailure("cell with identifier \(identifier) is not of type \(CellType.self)")
    }
    return cell
  }

  public func dequeueReusableHeaderFooterView<ViewType: UITableViewHeaderFooterView>() -> ViewType {
    let identifier = String(describing: ViewType.self)
    guard let cell = self.dequeueReusableHeaderFooterView(withIdentifier: identifier) as? ViewType else {
      preconditionFailure("view with identifier \(identifier) is not of type \(ViewType.self)")
    }
    return cell
  }
}

public protocol CollectionViewDequeuing {
  func dequeueReusableCell<CellType: UICollectionViewCell>(for indexPath: IndexPath) -> CellType
  func dequeueReusableSupplementaryView<ViewType: UICollectionReusableView>(ofKind elementKind: String,
                                                                            for indexPath: IndexPath) -> ViewType
}

extension UICollectionView: CollectionViewDequeuing {
  public func dequeueReusableCell<CellType: UICollectionViewCell>(for indexPath: IndexPath) -> CellType {
    let identifier = String(describing: CellType.self)
    guard let cell = self.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? CellType else {
      preconditionFailure("cell with identifier \(identifier) is not of type \(CellType.self)")
    }
    return cell
  }

  public func dequeueReusableSupplementaryView<ViewType: UICollectionReusableView>(
      ofKind elementKind: String,
      for indexPath: IndexPath) -> ViewType {
    let identifier = String(describing: ViewType.self)
    guard let cell = self.dequeueReusableSupplementaryView(ofKind: elementKind,
                                                           withReuseIdentifier: identifier,
                                                           for: indexPath) as? ViewType else {
      preconditionFailure("view with identifier \(identifier) is not of type \(ViewType.self)")
    }
    return cell
  }
}
