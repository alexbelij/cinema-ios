import UIKit
import Dispatch

class ReplaceLibraryViewController: UIViewController {

  private var library: MediaLibrary!
  private var newLibraryUrl: URL!

  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var label: UILabel!
  @IBOutlet weak var errorLabel: UILabel!
  @IBOutlet weak var closeButton: UIButton!
  @IBOutlet weak var centeringConstraint: NSLayoutConstraint!

  func replaceLibraryContent(of library: MediaLibrary, withContentOf url: URL) {
    self.library = library
    self.newLibraryUrl = url
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    label.text = NSLocalizedString("replaceLibrary.progress.text", comment: "")
    closeButton.setTitle(NSLocalizedString("ok", comment: ""), for: .normal)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    activityIndicator.startAnimating()
    DispatchQueue.global(qos: .userInitiated).async {
      var libraryError: Error? = nil
      do {
        let mediaItems = try JSONFormat().deserialize(from: Data(contentsOf: self.newLibraryUrl))
        try self.library.replaceItems(mediaItems)
      } catch let error {
        libraryError = error
      }
      do {
        try FileManager.default.removeItem(at: self.newLibraryUrl)
      } catch {
        fatalError("Could not delete inbox file at \(self.newLibraryUrl)")
      }
      DispatchQueue.main.async {
        self.activityIndicator.stopAnimating()
        if libraryError == nil {
          self.label.text = NSLocalizedString("replaceLibrary.done.success.text", comment: "")
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.dismiss()
          }
        } else {
          self.label.text = NSLocalizedString("replaceLibrary.done.failure.text", comment: "")
          switch libraryError! {
            case DataFormatError.invalidDataFormat:
              self.errorLabel.text = NSLocalizedString("error.invalidDataFormat", comment: "")
            case MediaLibraryError.storageError:
              self.errorLabel.text = NSLocalizedString("error.storageError", comment: "")
            default:
              self.errorLabel.text = NSLocalizedString("error.genericError", comment: "")
          }
          self.errorLabel.isHidden = false
          self.closeButton.isHidden = false
          self.view?.superview?.layoutIfNeeded()
          let extraHeight = self.closeButton.frame.origin.y - self.errorLabel.frame.origin.y
          UIView.animate(withDuration: 0.3) {
            self.centeringConstraint.constant = -extraHeight / 2
            self.view?.superview?.layoutIfNeeded()
          }
        }
      }
    }
  }

  @IBAction private func dismiss() {
    self.dismiss(animated: true)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    activityIndicator.stopAnimating()
  }
}
