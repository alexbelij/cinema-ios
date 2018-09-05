import CinemaKit
import Dispatch
import UIKit

class LibraryListController: UITableViewController {
  private enum LibraryItem {
    case placeholder(MovieLibraryMetadata)
    case selectLibrary(MovieLibraryMetadata)
    case addLibraryAction
  }

  private static let sortDescriptor: (LibraryItem, LibraryItem) -> Bool = { item1, item2 in
    switch (item1, item2) {
      case let (.placeholder(metadata1), .placeholder(metadata2)):
        return StandardSortDescriptors.byMetadataName(metadata1, metadata2)
      case let (.selectLibrary(metadata1), .selectLibrary(metadata2)):
        return StandardSortDescriptors.byMetadataName(metadata1, metadata2)
      case let (.placeholder(metadata1), .selectLibrary(metadata2)):
        return StandardSortDescriptors.byMetadataName(metadata1, metadata2)
      case let (.selectLibrary(metadata1), .placeholder(metadata2)):
        return StandardSortDescriptors.byMetadataName(metadata1, metadata2)
      case (.addLibraryAction, _): return false
      case (_, .addLibraryAction): return true
    }
  }
  var onDoneButtonTap: (() -> Void)?
  var onSelection: ((MovieLibraryMetadata) -> Void)?
  var onAddLibraryButtonTap: (() -> Void)?

  private var libraryItems = [LibraryItem.addLibraryAction]
}

// MARK: - Setup

extension LibraryListController {
  func setLibraries(_ data: [MovieLibraryMetadata]) {
    libraryItems = data.map { LibraryItem.selectLibrary($0) } + [.addLibraryAction]
    libraryItems.sort(by: LibraryListController.sortDescriptor)
    tableView?.reloadData()
  }

  func showPlaceholder(for metadata: MovieLibraryMetadata) {
    showLibraryItem(.placeholder(metadata), with: metadata)
  }

  func showLibrary(with metadata: MovieLibraryMetadata) {
    showLibraryItem(.selectLibrary(metadata), with: metadata)
  }

  private func showLibraryItem(_ newItem: LibraryItem, with metadata: MovieLibraryMetadata) {
    if let oldIndex = libraryItemIndex(for: metadata) {
      let shouldUpdate: Bool
      switch (libraryItems[oldIndex], newItem) {
        case let (.placeholder(oldMetadata), .placeholder),
             let (.selectLibrary(oldMetadata), .selectLibrary):
          shouldUpdate = oldMetadata != metadata
        default:
          shouldUpdate = true
      }
      if shouldUpdate {
        libraryItems.remove(at: oldIndex)
        libraryItems.append(newItem)
        libraryItems.sort(by: LibraryListController.sortDescriptor)
        let newIndex = libraryItemIndex(for: metadata)!
        if oldIndex != newIndex {
          tableView.moveRow(at: IndexPath(row: oldIndex, section: 0), to: IndexPath(row: newIndex, section: 0))
        }
        tableView.reloadRows(at: [IndexPath(row: newIndex, section: 0)], with: .automatic)
      }
    } else {
      libraryItems.append(newItem)
      libraryItems.sort(by: LibraryListController.sortDescriptor)
      let newIndex = libraryItemIndex(for: metadata)!
      tableView.insertRows(at: [IndexPath(row: newIndex, section: 0)], with: .automatic)
    }
  }

  func removeItem(for metadata: MovieLibraryMetadata) {
    guard let index = libraryItemIndex(for: metadata) else { return }
    libraryItems.remove(at: index)
    tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  private func libraryItemIndex(for metadata: MovieLibraryMetadata) -> Int? {
    return libraryItems.index {
      switch $0 {
        case let .placeholder(metadata1): return metadata1.id == metadata.id
        case let .selectLibrary(metadata1): return metadata1.id == metadata.id
        case .addLibraryAction: return false
      }
    }
  }
}

// MARK: - Table View

extension LibraryListController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
      case 0: return libraryItems.count
      default: fatalError("unexpected section \(section)")
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
      case 0:
        switch libraryItems[indexPath.row] {
          case let .placeholder(metadata):
            let cell: PlaceholderTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(for: metadata)
            return cell
          case let .selectLibrary(metadata):
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExistingLibraryTableCell", for: indexPath)
            cell.textLabel!.text = metadata.name
            return cell
          case .addLibraryAction:
            return tableView.dequeueReusableCell(for: indexPath) as AddNewLibraryTableCell
        }
      default:
        fatalError("unexpected section \(indexPath.section)")
    }
  }

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    switch indexPath.section {
      case 0:
        switch libraryItems[indexPath.row] {
          case .placeholder: return nil
          case .selectLibrary, .addLibraryAction: return indexPath
        }
      default:
        fatalError("unexpected section \(indexPath.section)")
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch indexPath.section {
      case 0:
        switch libraryItems[indexPath.row] {
          case .placeholder:
            fatalError("should not be selectable")
          case let .selectLibrary(metadata):
            onSelection?(metadata)
          case .addLibraryAction:
            onAddLibraryButtonTap?()
            tableView.deselectRow(at: indexPath, animated: true)
        }
      default:
        fatalError("unexpected section \(indexPath.section)")
    }
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return NSLocalizedString("libraryList.libraries", comment: "")
      default: fatalError("unexpected section \(section)")
    }
  }
}

// MARK: - User Actions

extension LibraryListController {
  @IBAction private func doneButtonTapped() {
    onDoneButtonTap?()
  }
}

class PlaceholderTableCell: UITableViewCell {
  @IBOutlet private weak var label: UILabel!
  @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

  func configure(for metadata: MovieLibraryMetadata) {
    label.text = metadata.name
    activityIndicator.startAnimating()
  }
}

class AddNewLibraryTableCell: UITableViewCell {
  @IBOutlet private weak var label: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    label.textColor = tintColor
    label.text = NSLocalizedString("libraryList.addNewLibrary", comment: "")
  }
}
