import UIKit

struct SelectableLabelSheetItem: SheetItemProtocol {
  let title: String
  let accessoryType: UITableViewCell.AccessoryType
  let groupingStyle: SheetItemGroupingStyle
  let handler: ((SelectableLabelSheetItem) -> Void)?

  init(title: String,
       showCheckmark: Bool,
       groupingStyle: SheetItemGroupingStyle = .grouped,
       handler: ((SelectableLabelSheetItem) -> Void)? = nil) {
    self.title = title
    self.accessoryType = showCheckmark ? .checkmark : .none
    self.groupingStyle = groupingStyle
    self.handler = handler
  }
}

class SelectableLabelCell: UITableViewCell {
  @IBOutlet private var label: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    label.textColor = tintColor
  }

  func configure(labelText: String, accessoryType: UITableViewCell.AccessoryType = .none) {
    label.text = labelText
    self.accessoryType = accessoryType
  }
}

class SelectableLabelCellConfig: TabularSheetCellConfiguration {
  typealias SheetItem = SelectableLabelSheetItem

  let nibCellTypes: [UITableViewCell.Type] = [SelectableLabelCell.self]

  func cell(for sheetItem: SelectableLabelSheetItem,
            at indexPath: IndexPath,
            cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    let cell: SelectableLabelCell = cellDequeuing.dequeueReusableCell(for: indexPath)
    cell.configure(labelText: sheetItem.title, accessoryType: sheetItem.accessoryType)
    return cell
  }

  var localizedCancelString: String {
    return NSLocalizedString("cancel", comment: "")
  }
}
