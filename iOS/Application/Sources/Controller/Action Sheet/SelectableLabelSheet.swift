import UIKit

struct SelectableLabelSheetItem: SheetItemProtocol {
  let title: String
  let accessoryType: UITableViewCellAccessoryType
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
  @IBOutlet private weak var label: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    label.textColor = tintColor
  }

  func configure(labelText: String, accessoryType: UITableViewCellAccessoryType = .none) {
    label.text = labelText
    self.accessoryType = accessoryType
  }
}

class SelectableLabelCellConfig: TabularSheetCellConfiguration {
  typealias SheetItem = SelectableLabelSheetItem

  let nibCellTypes: [UITableViewCell.Type] = [SelectableLabelCell.self]

  func cell(for sheetItem: SelectableLabelSheetItem,
            at indexPath: IndexPath,
            cellDequeuing: CellDequeuing) -> UITableViewCell {
    let cell = cellDequeuing.dequeueReusableCell(SelectableLabelCell.self, for: indexPath)
    cell.configure(labelText: sheetItem.title, accessoryType: sheetItem.accessoryType)
    return cell
  }

  var localizedCancelString: String {
    return NSLocalizedString("cancel", comment: "")
  }
}
