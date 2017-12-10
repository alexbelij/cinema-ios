import Dispatch
import UIKit

class SearchResultsController: UIViewController {

  @IBOutlet private weak var tableView: UITableView!
  private lazy var emptyView = GenericEmptyView()
  private var previousTableViewInsets: UIEdgeInsets?

  var searchText: String = "" {
    didSet {
      DispatchQueue.main.async {
        self.emptyView.configure(
            accessory: .image(#imageLiteral(resourceName: "EmptySearchResults")),
            description: .basic(.localizedStringWithFormat(NSLocalizedString("search.results.empty", comment: ""),
                                                           self.searchText))
        )
      }
    }
  }
  var searchResults = [SearchResult]() {
    didSet {
      DispatchQueue.main.async {
        if self.searchResults.isEmpty {
          self.tableView.backgroundView = self.emptyView
          self.tableView.separatorStyle = .none
        } else {
          self.tableView.backgroundView = nil
          self.tableView.separatorStyle = .singleLine
        }
        self.tableView.reloadData()
      }
    }
  }
  weak var delegate: SearchResultsSelectionDelegate?

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.delegate = self
    tableView.dataSource = self
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardDidShow(_:)),
                                   name: .UIKeyboardDidShow,
                                   object: nil)
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillHide(_:)),
                                   name: .UIKeyboardWillHide,
                                   object: nil)
  }

  struct SearchResult {
    let item: PartialMediaItem
    let hasBeenAddedToLibrary: Bool

    init(item: PartialMediaItem, hasBeenAddedToLibrary: Bool) {
      self.item = item
      self.hasBeenAddedToLibrary = hasBeenAddedToLibrary
    }
  }
}

// MARK: - Table View

extension SearchResultsController: UITableViewDataSource, UITableViewDelegate {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchResults.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let searchResult = searchResults[indexPath.row]
    if searchResult.hasBeenAddedToLibrary {
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemAddedCell",
                                               // swiftlint:disable:next force_cast
                                               for: indexPath) as! SearchItemAddedCell
      cell.configure(for: searchResult.item)
      return cell
    } else {
      // swiftlint:disable:next force_cast
      let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemCell", for: indexPath) as! SearchItemCell
      cell.configure(for: searchResult.item)
      return cell
    }
  }

  func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return searchResults[indexPath.row].hasBeenAddedToLibrary ? nil : indexPath
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    delegate?.didSelectSearchResult(searchResults[indexPath.row].item)
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

// MARK: - Keyboard Adjustments

extension SearchResultsController {
  @objc
  private func keyboardDidShow(_ notification: Notification) {
    guard let keyboardFrame = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect else { return }
    var contentInsets: UIEdgeInsets
    if previousTableViewInsets == nil {
      contentInsets = tableView.contentInset
      self.previousTableViewInsets = contentInsets
    } else {
      contentInsets = tableView.contentInset
    }
    if #available(iOS 11.0, *) {
      contentInsets.bottom = keyboardFrame.height - view.safeAreaInsets.bottom
    } else {
      contentInsets.bottom = keyboardFrame.height
    }
    self.tableView.contentInset = contentInsets
    self.tableView.scrollIndicatorInsets = contentInsets
  }

  @objc
  private func keyboardWillHide(_ notification: Notification) {
    guard let insets = self.previousTableViewInsets else { return }
    UIView.animate(withDuration: 0.3) {
      self.tableView.contentInset = insets
      self.tableView.scrollIndicatorInsets = insets
    }
    self.previousTableViewInsets = nil
  }
}

protocol SearchResultsSelectionDelegate: class {
  func didSelectSearchResult(_ searchResult: PartialMediaItem)
}

class SearchItemCell: UITableViewCell {
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var yearLabel: UILabel!

  func configure(for searchItem: PartialMediaItem) {
    titleLabel.text = searchItem.title
    if let releaseDate = searchItem.releaseDate {
      let calendar = Calendar.current
      yearLabel.text = String(calendar.component(.year, from: releaseDate))
    }
  }
}

class SearchItemAddedCell: UITableViewCell {

  @IBOutlet private weak var titleLabel: UILabel!

  func configure(for searchItem: PartialMediaItem) {
    titleLabel.text = searchItem.title
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    self.tintColor = .disabledControlText
  }
}
