import CinemaKit
import UIKit

class LibrarySettingsController: UITableViewController {
  enum Section: Equatable {
    case name
    case share
    case shareOptions
    case delete

    var header: String? {
      switch self {
        case .name: return NSLocalizedString("librarySettings.nameSection.header", comment: "")
        case .share, .shareOptions: return NSLocalizedString("librarySettings.shareSection.header", comment: "")
        case .delete: return nil
      }
    }

    var isSelectable: Bool {
      switch self {
        case .name: return false
        case .share, .shareOptions, .delete: return true
      }
    }
  }

  var metadata: MovieLibraryMetadata {
    didSet {
      guard isViewLoaded else { return }
      configure(for: metadata)
    }
  }
  private var originalMetadata: MovieLibraryMetadata!
  private var updatedMetadata: MovieLibraryMetadata!
  var onMetadataUpdate: ((MovieLibraryMetadata) -> Void)?
  var onShareButtonTap: (() -> Void)?
  var onRemoveLibrary: (() -> Void)?
  var onDisappear: (() -> Void)?
  private var viewModel: [Section]!

  private var shouldIgnoreEdits = false

  init(for metadata: MovieLibraryMetadata) {
    self.metadata = metadata
    super.init(style: .grouped)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("use LibrarySettingsController.init() instead")
  }
}

// MARK: - View Controller Lifecycle

extension LibrarySettingsController {
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(TextFieldTableCell.self)
    tableView.register(MessageTableCell.self)
    tableView.register(ButtonTableCell.self)
    tableView.keyboardDismissMode = .onDrag
    configure(for: metadata)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    view.endEditing(true)
    commitMetadataEdits()
    if isMovingFromParentViewController {
      onDisappear?()
    }
  }
}

// MARK: - Setup

extension LibrarySettingsController {
  private func configure(for metadata: MovieLibraryMetadata) {
    viewModel = [.name, metadata.isShared ? .shareOptions : .share]
    if metadata.isCurrentUserOwner {
      viewModel.append(.delete)
    }
    originalMetadata = metadata
    updatedMetadata = metadata
    tableView.reloadData()
  }

  private func commitMetadataEdits() {
    if shouldIgnoreEdits { return }
    if updatedMetadata.name.isEmpty {
      updatedMetadata.name = originalMetadata.name
    }
    if updatedMetadata != originalMetadata {
      onMetadataUpdate?(updatedMetadata)
      originalMetadata = updatedMetadata
    }
  }
}

// MARK: - Table View

extension LibrarySettingsController {
  override func numberOfSections(in tableView: UITableView) -> Int {
    return viewModel.count
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch viewModel![section] {
      case .name: return updatedMetadata.name.isEmpty ? 2 : 1
      default: return 1
    }
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return viewModel![section].header
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    switch viewModel![section] {
      case .shareOptions:
        return metadata.isCurrentUserOwner
            ? nil
            : NSLocalizedString("librarySettings.howToRemoveSharedLibrary", comment: "")
      default: return nil
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch viewModel![indexPath.section] {
      case .name:
        switch indexPath.row {
          case 0:
            let cell: TextFieldTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.onChange = { [weak self] newText in
              guard let `self` = self else { return }
              let oldText = self.updatedMetadata!.name
              self.updatedMetadata.name = newText
              if oldText.isEmpty && !newText.isEmpty {
                let section = self.viewModel.index(of: .name)!
                self.tableView.deleteRows(at: [IndexPath(row: 1, section: section)], with: .fade)
              } else if !oldText.isEmpty && newText.isEmpty {
                let section = self.viewModel.index(of: .name)!
                self.tableView.insertRows(at: [IndexPath(row: 1, section: section)], with: .fade)
              }
            }
            cell.textValue = updatedMetadata.name
            cell.isEnabled = metadata.currentUserCanModify
            return cell
          default:
            let cell: MessageTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.message = NSLocalizedString("librarySettings.nameSection.notEmptyMessage", comment: "")
            cell.messageStyle = .error
            return cell
        }
      case .share:
        let cell: ButtonTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.actionTitle = NSLocalizedString("librarySettings.shareLibrary", comment: "")
        cell.buttonStyle = .default
        cell.actionTitleAlignment = .left
        return cell
      case .shareOptions:
        let cell: ButtonTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.actionTitle = NSLocalizedString("librarySettings.shareOptions", comment: "")
        cell.buttonStyle = .default
        cell.actionTitleAlignment = .left
        return cell
      case .delete:
        let cell: ButtonTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.actionTitle = NSLocalizedString("librarySettings.deleteSection.delete", comment: "")
        cell.buttonStyle = .destructive
        cell.actionTitleAlignment = .center
        return cell
    }
  }

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return viewModel![indexPath.section].isSelectable ? indexPath : nil
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    view.endEditing(false)
    switch viewModel![indexPath.section] {
      case .name:
        break
      case .share, .shareOptions:
        commitMetadataEdits()
        onShareButtonTap?()
      case .delete:
        let alert: UIAlertController
        let deleteActionTitle: String
        if metadata.isShared {
          alert = UIAlertController(
              title: NSLocalizedString("librarySettings.removeLibrary.shared.alert.title", comment: ""),
              message: NSLocalizedString("librarySettings.removeLibrary.shared.alert.message", comment: ""),
              preferredStyle: .alert)
          deleteActionTitle = NSLocalizedString("librarySettings.removeLibrary.shared.actionTitle", comment: "")
        } else {
          alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
          let format = NSLocalizedString("librarySettings.removeLibrary.private.actionTitleFormat", comment: "")
          deleteActionTitle = .localizedStringWithFormat(format, updatedMetadata.name)
        }
        alert.addAction(UIAlertAction(title: deleteActionTitle, style: .destructive) { _ in
          self.shouldIgnoreEdits = true
          self.onRemoveLibrary?()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
}
