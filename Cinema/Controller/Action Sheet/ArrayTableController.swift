import UIKit

class ArrayTableController<SheetItem: SheetItemProtocol>: NSObject, UITableViewDataSource, UITableViewDelegate {

  private let sheetItemType: SheetItemType
  private let cellConfig: AnyTabularSheetCellConfiguration<SheetItem>
  private let tableViewWrapper = TableViewWrapper()
  private unowned let presentingViewController: UIViewController

  init(sheetItemType: SheetItemType,
       cellConfig: AnyTabularSheetCellConfiguration<SheetItem>,
       presentingViewController: UIViewController) {
    self.sheetItemType = sheetItemType
    self.cellConfig = cellConfig
    self.presentingViewController = presentingViewController
  }

  // MARK: - UITableViewDataSource

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch sheetItemType {
      case let .array(array): return array.count
      case .cancel: return 1
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    self.tableViewWrapper.tableView = tableView
    self.tableViewWrapper.indexPath = indexPath
    switch sheetItemType {
      case let .array(array):
        return self.cellConfig.cell(for: array[indexPath.item], cellDequeuing: tableViewWrapper)
      case .cancel:
        return self.cellConfig.cancelCell(cellDequeuing: tableViewWrapper)
    }
  }

  // MARK: - UITableViewDelegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch sheetItemType {
      case let .array(array):
        let item = array[indexPath.item]
        DispatchQueue.main.async {
          self.presentingViewController.dismiss(animated: true) { item.handler?(item) }
        }
      case .cancel:
        DispatchQueue.main.async {
          self.presentingViewController.dismiss(animated: true)
        }
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return self.cellConfig.cellHeight
  }

  func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
    return self.cellConfig.cellHeight
  }

  enum SheetItemType {
    case array([SheetItem])
    case cancel
  }
}

private class TableViewWrapper: CellDequeuing {
  fileprivate var tableView: UITableView?
  fileprivate var indexPath: IndexPath?

  func dequeueReusableCell<CellType: UITableViewCell>(withIdentifier identifier: String) -> CellType {
    guard let tableView = self.tableView, let indexPath = self.indexPath else { preconditionFailure() }
    guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? CellType else {
      preconditionFailure("cell with identifier \(identifier) is not of type \(CellType.self)")
    }
    return cell
  }
}
