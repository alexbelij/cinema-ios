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

  func addPlaceholder(for metadata: MovieLibraryMetadata) {
    viewModel.append(.placeholder(metadata))
    viewModel.sort(by: LibraryListController.sortDescriptor)
    let index = viewModelIndex(for: metadata)!
    tableView?.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  func showPlaceholder(for metadata: MovieLibraryMetadata) {
    guard let index = viewModelIndex(for: metadata) else { preconditionFailure("library not found") }
    viewModel.remove(at: index)
    viewModel.insert(.placeholder(metadata), at: index)
    tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  func hidePlaceholder(for metadata: MovieLibraryMetadata) {
    guard let index = viewModelIndex(for: metadata) else { preconditionFailure("placeholder not found") }
    viewModel.remove(at: index)
    viewModel.insert(.selectLibrary(metadata), at: index)
    tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }

  func removePlaceholder(for metadata: MovieLibraryMetadata) {
    guard let index = viewModelIndex(for: metadata) else { preconditionFailure("placeholder not found") }
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
      case let .placeholder(text):
        let cell: PlaceholderTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(for: text)
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
