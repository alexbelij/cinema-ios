import Foundation
import UIKit

protocol EditMovieControllerDelegate: class {
  func editMovieController(_ controller: EditMovieController,
                           shouldAcceptEdits edits: Set<EditMovieController.Edit>) -> EditMovieController.EditApproval
  func editMovieControllerDidCancelEditing(_ controller: EditMovieController)
  func editMovieController(_ controller: EditMovieController,
                           didFinishEditingWithResult editResult: EditMovieController.EditResult)
}

class EditMovieController: UITableViewController {
  weak var delegate: EditMovieControllerDelegate?

  var movieTitle: String = "" {
    didSet {
      self.loadViewIfNeeded()
      self.titleTextField.text = movieTitle
    }
  }
  @IBOutlet private weak var titleTextField: UITextField!

  var subtitle: String? {
    didSet {
      self.loadViewIfNeeded()
      self.subtitleTextField.text = subtitle
    }
  }
  @IBOutlet private weak var subtitleTextField: UITextField!

  @IBOutlet private weak var removeMovieButton: UIButton!

  enum Edit: Hashable {
    case titleChange(String)
    case subtitleChange(String?)

    var hashValue: Int {
      switch self {
        case .titleChange: return 0
        case .subtitleChange: return 1
      }
    }
  }

  enum EditResult {
    case edited(Set<Edit>)
    case deleted
  }

  enum EditApproval {
    case accepted
    case rejected(reason: String)
  }
}

// MARK: - View Controller Lifecycle

extension EditMovieController {
  override func viewDidLoad() {
    super.viewDidLoad()
    titleTextField.delegate = self
    subtitleTextField.delegate = self
    removeMovieButton.setTitle(NSLocalizedString("edit.removeMovie", comment: ""), for: .normal)

    reassign(property: \EditMovieController.movieTitle)
    reassign(property: \EditMovieController.subtitle)
  }

  private func reassign<Type>(property: ReferenceWritableKeyPath<EditMovieController, Type>) {
    let value = self[keyPath: property]
    self[keyPath: property] = value
  }
}

// MARK: - Table View

extension EditMovieController {
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return NSLocalizedString("edit.sectionHeader.title", comment: "")
      case 1: return NSLocalizedString("edit.sectionHeader.subtitle", comment: "")
      default: return nil
    }
  }
}

// MARK: - Edit Management

extension EditMovieController {
  private var allEdits: Set<Edit> {
    var edits = [Edit]()
    let newTitle = self.titleTextField.text ?? ""
    if newTitle != movieTitle {
      edits.append(.titleChange(newTitle))
    }
    let newSubtitle = self.subtitleTextField.text?.nilIfEmptyString
    if newSubtitle != subtitle {
      edits.append(.subtitleChange(newSubtitle))
    }
    return Set(edits)
  }
}

// MARK: - UITextFieldDelegate

extension EditMovieController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if let nextField = self.view.viewWithTag(textField.tag + 1) as? UITextField {
      nextField.becomeFirstResponder()
    } else {
      textField.resignFirstResponder()
    }
    return false
  }
}

// MARK: - User Actions

extension EditMovieController {
  @IBAction private func cancelButtonClicked() {
    dismissKeyboard()
    delegate?.editMovieControllerDidCancelEditing(self)
  }

  @IBAction private func doneButtonClicked() {
    dismissKeyboard()
    guard let delegate = self.delegate else { return }
    let edits = self.allEdits
    if edits.isEmpty {
      delegate.editMovieControllerDidCancelEditing(self)
    } else {
      switch delegate.editMovieController(self, shouldAcceptEdits: edits) {
        case .accepted:
          delegate.editMovieController(self, didFinishEditingWithResult: .edited(edits))
        case let .rejected(reason):
          let alert = UIAlertController(title: NSLocalizedString("error.genericTitle", comment: ""),
                                        message: reason,
                                        preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
          self.present(alert, animated: true)
      }
    }
  }

  @IBAction private func removeButtonClicked() {
    dismissKeyboard()
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: NSLocalizedString("edit.removeMovie", comment: ""),
                                  style: .destructive) { _ in
      self.delegate?.editMovieController(self, didFinishEditingWithResult: .deleted)
    })
    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel))
    self.present(alert, animated: true)
  }

  @IBAction private func dismissKeyboard() {
    self.view?.endEditing(false)
  }
}

extension EditMovieController {
  func startWaitingAnimation() {
    navigationItem.leftBarButtonItem!.isEnabled = false
    titleTextField.isUserInteractionEnabled = false
    subtitleTextField.isUserInteractionEnabled = false
    removeMovieButton.isUserInteractionEnabled = false
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    activityIndicator.startAnimating()
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
  }

  func stopWaitingAnimation(restoreUI: Bool) {
    navigationItem.leftBarButtonItem!.isEnabled = true
    titleTextField.isUserInteractionEnabled = true
    subtitleTextField.isUserInteractionEnabled = true
    removeMovieButton.isUserInteractionEnabled = true
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                        target: self,
                                                        action: #selector(doneButtonClicked))
  }
}
