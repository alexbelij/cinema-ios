import UIKit

class ArrayTableController<SheetItem: SheetItemProtocol>: NSObject, UITableViewDataSource, UITableViewDelegate {
  private let sheetItemType: SheetItemType
  private let cellConfig: AnyTabularSheetCellConfiguration<SheetItem>
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
    switch sheetItemType {
      case let .array(array):
        return self.cellConfig.cell(for: array[indexPath.item], at: indexPath, cellDequeuing: tableView)
      case .cancel:
        return self.cellConfig.cancelCell(for: indexPath, cellDequeuing: tableView)
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
