import CinemaKit
import Foundation
import UIKit

protocol EditMovieControllerDelegate: class {
  func editMovieControllerDidCancelEditing(_ controller: EditMovieController)
  func editMovieController(_ controller: EditMovieController,
                           didFinishEditingWith editResult: EditMovieController.EditResult)
}

class EditMovieController: UITableViewController {
  enum Section: Equatable {
    case title
    case subtitle
    case delete

    var header: String? {
      switch self {
        case .title: return NSLocalizedString("edit.sectionHeader.title", comment: "")
        case .subtitle: return NSLocalizedString("edit.sectionHeader.subtitle", comment: "")
        case .delete: return nil
      }
    }

    var isSelectable: Bool {
      switch self {
        case .title, .subtitle: return false
        case .delete: return true
      }
    }
  }

  weak var delegate: EditMovieControllerDelegate?

  var movie: Movie! {
    didSet {
      guard isViewLoaded else { return }
      configure(for: movie!)
    }
  }

  private var originalMovie: Movie!
  private var updatedMovie: Movie!
  private var viewModel: [Section]!
  private var showsActivityIndicatorInDeleteSection = false

  enum EditResult {
    case edited(Movie)
    case deleted
  }
}

// MARK: - View Controller Lifecycle

extension EditMovieController {
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(TextFieldTableCell.self)
    tableView.register(MessageTableCell.self)
    tableView.register(ButtonTableCell.self)
    configure(for: movie!)
  }
}

// MARK: - Setup

extension EditMovieController {
  private func configure(for movie: Movie) {
    viewModel = [.title, .subtitle, .delete]
    originalMovie = movie
    updatedMovie = movie
    tableView.reloadData()
  }
}

// MARK: - Table View

extension EditMovieController {
  override func numberOfSections(in tableView: UITableView) -> Int {
    return viewModel.count
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch viewModel![section] {
      case .title: return updatedMovie.title.isEmpty ? 2 : 1
      default: return 1
    }
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return viewModel![section].header
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch viewModel![indexPath.section] {
      case .title:
        switch indexPath.row {
          case 0:
            let cell: TextFieldTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.onChange = { [weak self] newText in
              guard let `self` = self else { return }
              let oldText = self.updatedMovie!.title
              self.updatedMovie.title = newText
              if oldText.isEmpty && !newText.isEmpty {
                let section = self.viewModel.index(of: .title)!
                self.tableView.deleteRows(at: [IndexPath(row: 1, section: section)], with: .fade)
                self.navigationItem.rightBarButtonItem!.isEnabled = true
              } else if !oldText.isEmpty && newText.isEmpty {
                let section = self.viewModel.index(of: .title)!
                self.tableView.insertRows(at: [IndexPath(row: 1, section: section)], with: .fade)
                self.navigationItem.rightBarButtonItem!.isEnabled = false
              }
            }
            cell.textValue = updatedMovie.title
            return cell
          default:
            let cell: MessageTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.message = NSLocalizedString("librarySettings.nameSection.notEmptyMessage", comment: "")
            cell.messageStyle = .error
            return cell
        }
      case .subtitle:
        let cell: TextFieldTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.onChange = { [weak self] newText in
          guard let `self` = self else { return }
          self.updatedMovie.subtitle = newText.nilIfEmptyString
        }
        cell.textValue = updatedMovie.subtitle ?? ""
        return cell
      case .delete:
        let cell: ButtonTableCell = tableView.dequeueReusableCell(for: indexPath)
        cell.actionTitle = NSLocalizedString("edit.removeMovie", comment: "")
        cell.buttonStyle = .destructive
        cell.actionTitleAlignment = .center
        cell.showsActivityIndicator = showsActivityIndicatorInDeleteSection
        return cell
    }
  }

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return viewModel![indexPath.section].isSelectable ? indexPath : nil
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    view.endEditing(false)
    switch viewModel![indexPath.section] {
      case .title, .subtitle:
        break
      case .delete:
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("edit.removeMovie", comment: ""),
                                      style: .destructive) { _ in
          let editResult = EditResult.deleted
          self.startWaitingAnimation(for: editResult)
          self.delegate?.editMovieController(self, didFinishEditingWith: editResult)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
        self.present(alert, animated: true)
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

// MARK: - User Actions

extension EditMovieController {
  @IBAction private func cancelButtonClicked() {
    view.endEditing(true)
    delegate?.editMovieControllerDidCancelEditing(self)
  }

  @IBAction private func doneButtonClicked() {
    view.endEditing(true)
    guard let delegate = self.delegate else { return }
    if updatedMovie.title == originalMovie.title && updatedMovie.subtitle == originalMovie.subtitle {
      delegate.editMovieControllerDidCancelEditing(self)
    } else {
      startWaitingAnimation(for: .edited(updatedMovie))
      delegate.editMovieController(self, didFinishEditingWith: .edited(updatedMovie))
    }
  }
}

extension EditMovieController {
  private func startWaitingAnimation(for editResult: EditResult) {
    tableView.visibleCells.forEach { cell in
      cell.isUserInteractionEnabled = false
    }
    switch editResult {
      case .edited:
        UIView.animate(withDuration: 0.1) { () -> Void in
          self.navigationItem.leftBarButtonItem!.isEnabled = false
        }
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        navigationItem.setRightBarButton(UIBarButtonItem(customView: activityIndicator), animated: true)
        activityIndicator.startAnimating()
      case .deleted:
        UIView.animate(withDuration: 0.1) { () -> Void in
          self.navigationItem.leftBarButtonItem!.isEnabled = false
          self.navigationItem.rightBarButtonItem!.isEnabled = false
        }
        showsActivityIndicatorInDeleteSection = true
        if let index = viewModel.index(of: .delete) {
          tableView.reloadRows(at: [IndexPath(row: 0, section: index)], with: .automatic)
        }
    }
  }

  func stopWaitingAnimation() {
    tableView.visibleCells.forEach { cell in
      cell.isUserInteractionEnabled = true
    }
    showsActivityIndicatorInDeleteSection = false
    if let index = viewModel.index(of: .delete) {
      tableView.reloadRows(at: [IndexPath(row: 0, section: index)], with: .automatic)
    }
    UIView.animate(withDuration: 0.1) { () -> Void in
      self.navigationItem.leftBarButtonItem!.isEnabled = true
    }
    let doneButton = UIBarButtonItem(barButtonSystemItem: .done,
                                     target: self,
                                     action: #selector(doneButtonClicked))
    navigationItem.setRightBarButton(doneButton, animated: true)
  }
}
