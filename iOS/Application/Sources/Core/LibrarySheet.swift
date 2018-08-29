import UIKit

enum LibrarySheetItem: SheetItemProtocol {
  case library(name: String, shared: Bool, selected: Bool, handler: (LibrarySheetItem) -> Void)
  case settings(handler: (LibrarySheetItem) -> Void)

  var groupingStyle: SheetItemGroupingStyle {
    return .grouped
  }
  var handler: ((LibrarySheetItem) -> Void)? {
    switch self {
      case let .library(_, _, _, handler): return handler
      case let .settings(handler): return handler
    }
  }
}

class SharedLibrarySheetCell: UITableViewCell {
  @IBOutlet private weak var sharedImageView: UIImageView!
  @IBOutlet private weak var label: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    sharedImageView.tintColor = tintColor
    label.textColor = tintColor
  }

  func configure(for sheetItem: LibrarySheetItem) {
    switch sheetItem {
      case let .library(name, shared, selected, _):
        sharedImageView.image = shared ? #imageLiteral(resourceName: "Shared") : nil
        label.text = name
        accessoryType = selected ? .checkmark : .none
      case .settings:
        sharedImageView.image = nil
        label.text = NSLocalizedString("core.librarySettings", comment: "")
        accessoryType = .none
    }
  }
}

class LibrarySheetCellConfig: TabularSheetCellConfiguration {
  typealias SheetItem = LibrarySheetItem

  let nibCellTypes: [UITableViewCell.Type] = [SharedLibrarySheetCell.self, SelectableLabelCell.self]
  private let sharedLibraryExists: Bool

  init(sharedLibraryExists: Bool) {
    self.sharedLibraryExists = sharedLibraryExists
  }

  func cell(for sheetItem: LibrarySheetItem,
            at indexPath: IndexPath,
            cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    if sharedLibraryExists {
      let cell: SharedLibrarySheetCell = cellDequeuing.dequeueReusableCell(for: indexPath)
      cell.configure(for: sheetItem)
      return cell
    } else {
      let cell: SelectableLabelCell = cellDequeuing.dequeueReusableCell(for: indexPath)
      switch sheetItem {
        case let .library(name, _, selected, _):
          cell.configure(labelText: name, accessoryType: selected ? .checkmark : .none)
        case .settings:
          cell.configure(labelText: NSLocalizedString("core.librarySettings", comment: ""))
      }
      return cell
    }
  }

  var localizedCancelString: String {
    return NSLocalizedString("cancel", comment: "")
  }
}
