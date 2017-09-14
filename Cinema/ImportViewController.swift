import Dispatch
import UIKit

class ImportViewController: UIViewController {
  
  private var library: MediaLibrary!
  private var newLibraryUrl: URL!
  
  @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet private weak var label: UILabel!
  @IBOutlet private weak var errorLabel: UILabel!
  @IBOutlet private weak var closeButton: UIButton!
  @IBOutlet private weak var centeringConstraint: NSLayoutConstraint!
  
  func importLibrary(contentOf url: URL, into library: MediaLibrary) {
    self.library = library
    self.newLibraryUrl = url
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    label.text = NSLocalizedString("import.progress.text", comment: "")
    closeButton.setTitle(NSLocalizedString("ok", comment: ""), for: .normal)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    activityIndicator.startAnimating()
    DispatchQueue.global(qos: .userInitiated).async {
      var libraryError: Error? = nil
      do {
        let itemsToImport = try JSONFormat().deserialize(from: Data(contentsOf: self.newLibraryUrl))
        let existingItems = self.library.mediaItems { _ in true }
        let newItems = itemsToImport.filter { !existingItems.contains($0) }
        try self.library.performBatchUpdates {
          for item in newItems {
            try self.library.add(item)
          }
        }
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
          self.label.text = NSLocalizedString("import.done.success.text", comment: "")
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.dismiss()
          }
        } else {
          self.label.text = NSLocalizedString("import.done.failure.text", comment: "")
          self.errorLabel.text = Utils.localizedErrorMessage(for: libraryError!)
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