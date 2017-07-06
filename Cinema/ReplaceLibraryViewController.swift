import UIKit
import Dispatch

class ReplaceLibraryViewController: UIViewController {

  private var library: MediaLibrary!
  private var newLibraryUrl: URL!

  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var label: UILabel!

  func replaceLibraryContent(of library: MediaLibrary, withContentOf url: URL) {
    self.library = library
    self.newLibraryUrl = url
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    label.text = NSLocalizedString("replaceLibrary.progress.text", comment: "")
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
        } else {
          switch libraryError! {
            case DataFormatError.invalidDataFormat:
              self.label.text = NSLocalizedString("error.invalidDataFormat", comment: "")
            case MediaLibraryError.storageError:
              self.label.text = NSLocalizedString("error.storageError", comment: "")
            default:
              self.label.text = NSLocalizedString("error.genericError", comment: "")
          }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
          self.dismiss(animated: true)
        }
      }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    activityIndicator.stopAnimating()
  }
}
