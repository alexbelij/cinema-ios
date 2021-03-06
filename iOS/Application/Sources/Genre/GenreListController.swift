import CinemaKit
import Dispatch
import Foundation
import UIKit

protocol GenreListControllerDelegate: class {
  func genreListController(_ controller: GenreListController, didSelectGenre genreId: GenreIdentifier)
}

protocol GenreImageProvider {
  func genreImage(for genreId: GenreIdentifier) -> UIImage?
}

class EmptyGenreImageProvider: GenreImageProvider {
  func genreImage(for genreId: GenreIdentifier) -> UIImage? {
    return nil
  }
}

class GenreListController: UITableViewController {
  enum ListData {
    case loading
    case available([GenreIdentifier])
    case unavailable
  }

  weak var delegate: GenreListControllerDelegate?
  var listData: ListData = .loading {
    didSet {
      guard self.isViewLoaded else { return }
      reload()
    }
  }
  private var viewModel: [Genre]!
  var genreImageProvider: GenreImageProvider = EmptyGenreImageProvider() {
    didSet {
      DispatchQueue.main.async {
        self.clearGenreImages()
      }
    }
  }

  fileprivate class Genre {
    let id: GenreIdentifier
    let name: String
    var image: ImageState

    init(id: GenreIdentifier, name: String) {
      self.id = id
      self.name = name
      self.image = .unknown
    }
  }
}

// MARK: - View Controller Lifecycle

extension GenreListController {
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.prefetchDataSource = self
    title = NSLocalizedString("genres", comment: "")
    reload()
  }
}

// MARK: - Data Management

extension GenreListController {
  private func reload() {
    self.setupViewModel()
    if viewModel == nil || viewModel.isEmpty {
      self.refreshControl?.removeTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
      self.refreshControl = nil
    } else {
      let refreshControl = UIRefreshControl()
      refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
      self.refreshControl = refreshControl
    }
    self.tableView.reloadData()
    self.configureBackgroundView()
  }

  private func setupViewModel() {
    switch listData {
      case .loading, .unavailable:
        viewModel = nil
      case let .available(genreIds):
        viewModel = genreIds.compactMap { id in L10n.genreName(for: id).map { name in Genre(id: id, name: name) } }
                            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
  }

  private func configureBackgroundView() {
    let backgroundView: GenericEmptyView?
    let separatorStyle: UITableViewCell.SeparatorStyle
    switch listData {
      case .loading:
        backgroundView = GenericEmptyView(
            accessory: .activityIndicator,
            description: .basic(NSLocalizedString("loading", comment: ""))
        )
        separatorStyle = .none
      case let .available(genreIds):
        if genreIds.isEmpty {
          backgroundView = GenericEmptyView(
              accessory: .image(#imageLiteral(resourceName: "EmptyLibrary")),
              description: .basic(NSLocalizedString("library.empty", comment: ""))
          )
          separatorStyle = .none
        } else {
          backgroundView = nil
          separatorStyle = .singleLine
        }
      case .unavailable:
        backgroundView = GenericEmptyView(
            description: .basic(NSLocalizedString("error.genericError", comment: ""))
        )
        separatorStyle = .none
    }
    self.tableView.backgroundView = backgroundView
    self.tableView.separatorStyle = separatorStyle
  }

  private func clearGenreImages() {
    self.viewModel?.forEach { $0.image = .unknown }
  }

  @objc
  private func handleRefresh(_ refreshControl: UIRefreshControl) {
    self.clearGenreImages()
    self.tableView.reloadData()
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
      refreshControl.endRefreshing()
    }
  }
}

// MARK: - Table View

extension UITableView {
  fileprivate func reloadRow(for genre: GenreListController.Genre,
                             at indexPathProvider: @escaping () -> IndexPath?,
                             using genreImageProvider: GenreImageProvider) {
    guard let indexPath = indexPathProvider() else { return }
    if let cell = cellForRow(at: indexPath) as? GenreCell {
      configure(cell,
                for: genre,
                at: indexPathProvider,
                using: genreImageProvider)
    }
  }

  fileprivate func configure(_ cell: GenreCell,
                             for genre: GenreListController.Genre,
                             at indexPathProvider: @escaping () -> IndexPath?,
                             using genreImageProvider: GenreImageProvider) {
    cell.configure(for: genre, genreImageProvider: genreImageProvider) {
      guard let indexPath = indexPathProvider() else { return }
      if let cell = self.cellForRow(at: indexPath) as? GenreCell {
        self.configure(cell,
                       for: genre,
                       at: indexPathProvider,
                       using: genreImageProvider)
      }
    }
  }
}

extension GenreListController: UITableViewDataSourcePrefetching {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let viewModel = self.viewModel else { return 0 }
    return viewModel.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: GenreCell = tableView.dequeueReusableCell(for: indexPath)
    let genre = viewModel[indexPath.row]
    tableView.configure(cell,
                        for: genre,
                        at: { [weak self] in
                          self?.viewModel.firstIndex { $0.id == genre.id }
                                         .map { IndexPath(row: $0, section: 0) }
                        },
                        using: genreImageProvider)
    return cell
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 180
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.delegate?.genreListController(self, didSelectGenre: viewModel[indexPath.row].id)
  }

  func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      let genre = viewModel[indexPath.row]
      guard case .unknown = genre.image else { return }
      genre.image = .loading
      DispatchQueue.global(qos: .background).async {
        fetchBackdrop(for: genre, using: self.genreImageProvider) { [weak self] in
          guard let `self` = self else { return }
          tableView.reloadRow(for: genre,
                              at: { [weak self] in
                                self?.viewModel.firstIndex { $0.id == genre.id }
                                               .map { IndexPath(row: $0, section: 0) }
                              },
                              using: self.genreImageProvider)
        }
      }
    }
  }
}

// MARK: - Genre Cell

class GenreCell: UITableViewCell {
  @IBOutlet private var backdropImageView: UIImageView!
  @IBOutlet private var genreNameLabel: UILabel!
  @IBOutlet private var activityIndicator: UIActivityIndicatorView!
  private var scrim: ScrimView!

  override func awakeFromNib() {
    super.awakeFromNib()
    contentView.backgroundColor = .missingArtworkBackground
    scrim = ScrimView()
    contentView.insertSubview(scrim, belowSubview: genreNameLabel)
    genreNameLabel.layer.shadowColor = UIColor.black.cgColor
    genreNameLabel.layer.shadowOffset = .zero
    genreNameLabel.layer.shadowRadius = 5.0
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scrim.frame = contentView.bounds
  }

  fileprivate func configure(for genre: GenreListController.Genre,
                             genreImageProvider: GenreImageProvider,
                             onNeedsReload: @escaping () -> Void) {
    genreNameLabel.text = genre.name
    switch genre.image {
      case .unknown:
        configureBackdropForUnknownOrLoadingImageState()
        genre.image = .loading
        DispatchQueue.global(qos: .userInteractive).async {
          fetchBackdrop(for: genre, using: genreImageProvider, then: onNeedsReload)
        }
      case .loading:
        configureBackdropForUnknownOrLoadingImageState()
      case let .available(genreImage):
        genreNameLabel.textColor = .white
        genreNameLabel.layer.shadowOpacity = 1.0
        scrim.isHidden = false
        backdropImageView.contentMode = .scaleAspectFill
        configureBackdrop(genreImage)
        self.activityIndicator.stopAnimating()
      case .unavailable:
        genreNameLabel.textColor = #colorLiteral(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        genreNameLabel.layer.shadowOpacity = 0.0
        scrim.isHidden = true
        backdropImageView.contentMode = .center
        configureBackdrop(#imageLiteral(resourceName: "MissingGenreImage"))
        activityIndicator.stopAnimating()
    }
  }

  private func configureBackdropForUnknownOrLoadingImageState() {
    genreNameLabel.textColor = #colorLiteral(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    genreNameLabel.layer.shadowOpacity = 0.0
    scrim.isHidden = true
    configureBackdrop(nil)
    activityIndicator.startAnimating()
  }

  private func configureBackdrop(_ image: UIImage?) {
    backdropImageView.image = image
    if image == nil {
      backdropImageView.alpha = 0.0
    } else if backdropImageView.alpha < 1.0 {
      UIView.animate(withDuration: 0.2) {
        self.backdropImageView.alpha = 1.0
      }
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.activityIndicator.stopAnimating()
  }
}

private func fetchBackdrop(for genre: GenreListController.Genre,
                           using genreImageProvider: GenreImageProvider,
                           then completion: @escaping () -> Void) {
  let backdrop = genreImageProvider.genreImage(for: genre.id)
  DispatchQueue.main.async {
    if let backdropImage = backdrop {
      genre.image = .available(backdropImage)
    } else {
      genre.image = .unavailable
    }
    completion()
  }
}
