import UIKit

struct SortingSheetItem: SheetItemProtocol {
  let sortingName: String
  let isCurrentSorting: Bool
  let groupingStyle: SheetItemGroupingStyle = .grouped
  let handler: ((SortingSheetItem) -> Void)?

  init(sortingName: String, isCurrentSorting: Bool, handler: ((SortingSheetItem) -> Void)? = nil) {
    self.sortingName = sortingName
    self.isCurrentSorting = isCurrentSorting
    self.handler = handler
  }
}

class SortDescriptorCell: UITableViewCell {
  static let identifier = "SortDescriptorCell"

  @IBOutlet fileprivate weak var label: UILabel!
}

class SortingSheetCellConfig: TabularSheetCellConfiguration {
  typealias SheetItem = SortingSheetItem

  let nibCellReuseIdentifiers: [String] = [SortDescriptorCell.identifier]

  func cell(for sheetItem: SortingSheetItem, cellDequeuing: CellDequeuing) -> UITableViewCell {
    let cell = cellDequeuing.dequeueReusableCell(withIdentifier: SortDescriptorCell.identifier) as SortDescriptorCell
    cell.label.textColor = cell.tintColor
    cell.label.text = sheetItem.sortingName
    cell.accessoryType = sheetItem.isCurrentSorting ? .checkmark : .none
    return cell
  }

  var cancelString: String {
    return NSLocalizedString("cancel", comment: "")
  }
}
