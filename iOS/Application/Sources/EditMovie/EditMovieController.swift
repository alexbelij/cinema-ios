import CinemaKit
import Foundation
import UIKit

protocol EditMovieControllerDelegate: class {
  func editMovieControllerDidCancelEditing(_ controller: EditMovieController)
  func editMovieController(_ controller: EditMovieController,
                           didFinishEditingWith editResult: EditMovieController.EditResult)
}

class EditMovieController: UITableViewController {
  weak var delegate: EditMovieControllerDelegate?

  var movie: Movie! {
    didSet {
      guard isViewLoaded else { return }
      setup()
    }
  }

  @IBOutlet private weak var titleTextField: UITextField!
  @IBOutlet private weak var subtitleTextField: UITextField!

  @IBOutlet private weak var removeMovieButton: UIButton!
  @IBOutlet private weak var removeButtonActivityIndicator: UIActivityIndicatorView!

  enum EditResult {
    case edited(Movie)
    case deleted
  }
}

// MARK: - View Controller Lifecycle

extension EditMovieController {
  override func viewDidLoad() {
    super.viewDidLoad()
    titleTextField.delegate = self
    subtitleTextField.delegate = self
    removeMovieButton.setTitle(NSLocalizedString("edit.removeMovie", comment: ""), for: .normal)
    setup()
  }

  private func setup() {
    titleTextField.text = movie.title
    subtitleTextField.text = movie.subtitle
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

  @IBAction private func titleTextFieldDidChange(_ textField: UITextField) {
    let isTextFieldEmpty = titleTextField.text?.isEmpty ?? true
    navigationItem.rightBarButtonItem!.isEnabled = !isTextFieldEmpty
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
    let newTitle = self.titleTextField.text ?? ""
    let newSubtitle = self.subtitleTextField.text?.nilIfEmptyString
    if newTitle == movie.title && newSubtitle == movie.subtitle {
      delegate.editMovieControllerDidCancelEditing(self)
    } else {
      var editedMovie = movie!
      editedMovie.title = newTitle
      editedMovie.subtitle = newSubtitle
      startWaitingAnimation(for: .edited(editedMovie))
      delegate.editMovieController(self, didFinishEditingWith: .edited(editedMovie))
    }
  }

  @IBAction private func removeButtonClicked() {
    dismissKeyboard()
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

  @IBAction private func dismissKeyboard() {
    self.view?.endEditing(false)
  }
}

extension EditMovieController {
  private func startWaitingAnimation(for editResult: EditResult) {
    navigationItem.leftBarButtonItem!.isEnabled = false
    titleTextField.isUserInteractionEnabled = false
    subtitleTextField.isUserInteractionEnabled = false
    switch editResult {
      case .edited:
        removeMovieButton.isUserInteractionEnabled = false
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        activityIndicator.startAnimating()
      case .deleted:
        navigationItem.rightBarButtonItem!.isEnabled = false
        removeMovieButton.isHidden = true
        removeButtonActivityIndicator.startAnimating()
    }
  }

  func stopWaitingAnimation(restoreUI: Bool) {
    if navigationItem.rightBarButtonItem!.customView != nil {
      navigationItem.rightBarButtonItem = nil
    }
    removeButtonActivityIndicator.stopAnimating()
    if restoreUI {
      navigationItem.leftBarButtonItem!.isEnabled = true
      titleTextField.isUserInteractionEnabled = true
      subtitleTextField.isUserInteractionEnabled = true
      removeMovieButton.isUserInteractionEnabled = true
      removeMovieButton.isHidden = false
      navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                          target: self,
                                                          action: #selector(doneButtonClicked))
    }
  }
}
