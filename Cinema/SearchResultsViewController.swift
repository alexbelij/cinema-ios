import UIKit
import Dispatch

class SearchResultsController: UIViewController, UITableViewDelegate, UITableViewDataSource {

  @IBOutlet weak var tableView: UITableView!
  var searchResults = [PartialMediaItem]() {
    didSet {
      DispatchQueue.main.async {
        self.tableView.reloadData()
      }
    }
  }
  var delegate: SearchResultsSelectionDelegate!

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.delegate = self
    tableView.dataSource = self
  }

  // MARK: - Table view data source

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchResults.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "SearchItemCell", for: indexPath) as! SearchItemCell

    let searchItem = searchResults[indexPath.row]
    cell.titleLabel.text = searchItem.title
    if let year = searchItem.year, year != -1 {
      cell.yearLabel.text = String(year)
    }
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    delegate?.didSelectSearchResult(searchResults[indexPath.row])
  }

}

protocol SearchResultsSelectionDelegate {
  func didSelectSearchResult(_ searchResult: PartialMediaItem)
}
