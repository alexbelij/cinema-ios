import CinemaKit
import UIKit

class LibrarySettingsController: UITableViewController {
  enum Section: Equatable {
    case name
    case delete

    var header: String? {
      switch self {
        case .name: return NSLocalizedString("librarySettings.nameSection.header", comment: "")
        case .delete: return nil
      }
    }

    var isSelectable: Bool {
      switch self {
        case .name: return false
        case .delete: return true
      }
    }
  }

  var metadata: MovieLibraryMetadata! {
    didSet {
      guard metadata != nil else { preconditionFailure("metadata has not been set") }
      guard isViewLoaded else { return }
      configure(for: metadata)
    }
  }
  private var originalMetadata: MovieLibraryMetadata!
  private var updatedMetadata: MovieLibraryMetadata!
  var onMetadataUpdate: ((MovieLibraryMetadata) -> Void)?
  var onRemoveLibrary: (() -> Void)?
  var onDisappear: (() -> Void)?
  private var viewModel: [Section]!

  private var shouldIgnoreEdits = false
}

// MARK: - View Controller Lifecycle

extension LibrarySettingsController {
  override func viewDidLoad() {
    super.viewDidLoad()
    guard metadata != nil else { preconditionFailure("metadata has not been set") }
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
    viewModel = [.name, .delete]
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

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch viewModel![indexPath.section] {
      case .name:
        switch indexPath.row {
          case 0:
            let cell: TextFieldTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.shouldResignFirstResponderOnReturn = true
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
            return cell
          default:
            let cell: MessageTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.message = NSLocalizedString("librarySettings.nameSection.notEmptyMessage", comment: "")
            cell.messageStyle = .error
            return cell
        }
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
      case .delete:
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let format = NSLocalizedString("librarySettings.removeLibrary.private.actionTitleFormat", comment: "")
        alert.addAction(UIAlertAction(title: .localizedStringWithFormat(format, updatedMetadata.name),
                                      style: .destructive) { _ in
          self.shouldIgnoreEdits = true
          self.onRemoveLibrary?()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

class TextFieldTableCell: UITableViewCell, UITextFieldDelegate {
  @IBOutlet private weak var textField: UITextField!

  override func awakeFromNib() {
    super.awakeFromNib()
    textField.delegate = self
    textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
  }

  var textValue: String {
    get {
      return textField.text ?? ""
    }
    set {
      textField.text = newValue
    }
  }

  var shouldResignFirstResponderOnReturn: Bool = true

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if shouldResignFirstResponderOnReturn {
      textField.resignFirstResponder()
      return false
    } else {
      return true
    }
  }

  var onChange: ((String) -> Void)?

  @objc
  func textFieldDidChange(_ textField: UITextField) {
    onChange?(textField.text ?? "")
  }
}

class ButtonTableCell: UITableViewCell {
  enum ButtonStyle {
    case `default`
    case destructive
  }

  var actionTitle: String {
    get {
      return label.text ?? ""
    }
    set {
      label.text = newValue
    }
  }
  @IBOutlet private weak var label: UILabel!

  var actionTitleAlignment: NSTextAlignment = .left {
    didSet {
      label.textAlignment = actionTitleAlignment
    }
  }

  var buttonStyle: ButtonStyle = .default {
    didSet {
      switch buttonStyle {
        case .default:
          label.textColor = tintColor
        case .destructive:
          label.textColor = .destructive
      }
    }
  }
}

class MessageTableCell: UITableViewCell {
  enum MessageStyle {
    case `default`
    case error
  }

  var messageStyle: MessageStyle = .default {
    didSet {
      switch messageStyle {
        case .default:
          label.textColor = .black
        case .error:
          label.textColor = .red
      }
    }
  }

  var message: String {
    get {
      return label.text ?? ""
    }
    set {
      label.text = newValue
    }
  }
  @IBOutlet private weak var label: UILabel!
}
