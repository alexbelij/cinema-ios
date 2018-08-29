import CinemaKit
import Dispatch
import UIKit

class LibraryListController: UITableViewController {
  private enum ListItem {
    case placeholder(MovieLibraryMetadata)
    case selectLibrary(MovieLibraryMetadata)
    case addLibraryAction
  }

  private static let sortDescriptor: (ListItem, ListItem) -> Bool = { item1, item2 in
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

  private var viewModel = [ListItem.addLibraryAction]
}

// MARK: - Setup

extension LibraryListController {
  func setLibraries(_ data: [MovieLibraryMetadata]) {
    viewModel = data.map { ListItem.selectLibrary($0) } + [.addLibraryAction]
    viewModel.sort(by: LibraryListController.sortDescriptor)
    tableView?.reloadData()
  }

  func showPlaceholder(for metadata: MovieLibraryMetadata) {
    showItem(.placeholder(metadata), with: metadata)
  }

  func showLibrary(with metadata: MovieLibraryMetadata) {
    showItem(.selectLibrary(metadata), with: metadata)
  }

  private func showItem(_ newItem: ListItem, with metadata: MovieLibraryMetadata) {
    if let oldIndex = viewModelIndex(for: metadata) {
      let shouldUpdate: Bool
      switch (viewModel[oldIndex], newItem) {
        case let (.placeholder(oldMetadata), .placeholder),
             let (.selectLibrary(oldMetadata), .selectLibrary):
          shouldUpdate = oldMetadata != metadata
        default:
          shouldUpdate = true
      }
      if shouldUpdate {
        viewModel.remove(at: oldIndex)
        viewModel.append(newItem)
        viewModel.sort(by: LibraryListController.sortDescriptor)
        let newIndex = viewModelIndex(for: metadata)!
        if oldIndex != newIndex {
          tableView.moveRow(at: IndexPath(row: oldIndex, section: 0), to: IndexPath(row: newIndex, section: 0))
        }
        tableView.reloadRows(at: [IndexPath(row: newIndex, section: 0)], with: .automatic)
      }
    } else {
      viewModel.append(newItem)
      viewModel.sort(by: LibraryListController.sortDescriptor)
      let newIndex = viewModelIndex(for: metadata)!
      tableView.insertRows(at: [IndexPath(row: newIndex, section: 0)], with: .automatic)
    }
  }

  func removeItem(for metadata: MovieLibraryMetadata) {
    guard let index = viewModelIndex(for: metadata) else { return }
    viewModel.remove(at: index)
    tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  private func viewModelIndex(for metadata: MovieLibraryMetadata) -> Int? {
    return viewModel.index {
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
    return viewModel.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch viewModel[indexPath.row] {
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
  }

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    switch viewModel[indexPath.row] {
      case .placeholder: return nil
      case .selectLibrary, .addLibraryAction: return indexPath
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch viewModel[indexPath.row] {
      case .placeholder:
        fatalError("should not be selectable")
      case let .selectLibrary(metadata):
        onSelection?(metadata)
      case .addLibraryAction:
        onAddLibraryButtonTap?()
        tableView.deselectRow(at: indexPath, animated: true)
    }
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return NSLocalizedString("libraryList.libraries", comment: "")
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
