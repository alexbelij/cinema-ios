import Dispatch
import Foundation
import UIKit

protocol GenreListControllerDelegate: class {
  func genreListController(_ controller: GenreListController, didSelectGenre genreId: Int)
}

class GenreListController: UITableViewController {
  weak var delegate: GenreListControllerDelegate?
  var genreIds: [Int]? {
    didSet {
      guard self.isViewLoaded else { return }
      reload()
    }
  }
  private var viewModel = [Genre]()

  private struct Genre {
    let id: Int
    let name: String

    init(id: Int, name: String) {
      self.id = id
      self.name = name
    }
  }
}

// MARK: - View Controller Lifecycle

extension GenreListController {
  override func viewDidLoad() {
    super.viewDidLoad()
    reload()
  }
}

// MARK: - Data Management

extension GenreListController {
  private func reload() {
    self.setupViewModel()
    self.tableView.reloadData()
    self.configureBackgroundView()
  }

  private func setupViewModel() {
    if let genreIds = self.genreIds {
      viewModel = genreIds.flatMap { id in L10n.localizedGenreName(for: id).map { name in Genre(id: id, name: name) } }
                          .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    } else {
      viewModel = [Genre]()
    }
  }

  private func configureBackgroundView() {
    let backgroundView: GenericEmptyView?
    let separatorStyle: UITableViewCellSeparatorStyle
    if genreIds == nil {
      backgroundView = GenericEmptyView(
          description: .basic(NSLocalizedString("loading", comment: ""))
      )
      separatorStyle = .none
    } else if viewModel.isEmpty {
      backgroundView = GenericEmptyView(
          accessory: .image(#imageLiteral(resourceName: "EmptyLibrary")),
          description: .basic(NSLocalizedString("library.empty", comment: ""))
      )
      separatorStyle = .none
    } else {
      backgroundView = nil
      separatorStyle = .singleLine
    }
    self.tableView.backgroundView = backgroundView
    self.tableView.separatorStyle = separatorStyle
  }

}

// MARK: - Table View

extension GenreListController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModel.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "GenreCell", for: indexPath)
    cell.textLabel!.text = viewModel[indexPath.row].name
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.delegate?.genreListController(self, didSelectGenre: viewModel[indexPath.row].id)
  }
}
