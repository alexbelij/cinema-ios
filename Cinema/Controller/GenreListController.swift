import Dispatch
import Foundation
import UIKit

protocol GenreListControllerDelegate: class {
  func genreListController(_ controller: GenreListController, didSelectGenre genreId: Int)
}

protocol GenreImageProvider {
  func genreImage(for genreId: Int) -> UIImage?
}

class EmptyGenreImageProvider: GenreImageProvider {
  func genreImage(for genreId: Int) -> UIImage? {
    return nil
  }
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
  var genreImageProvider: GenreImageProvider = EmptyGenreImageProvider() {
    didSet {
      DispatchQueue.main.async {
        self.clearGenreImages()
      }
    }
  }

  fileprivate class Genre {
    let id: Int
    let name: String
    var image: Image

    init(id: Int, name: String) {
      self.id = id
      self.name = name
      self.image = .unknown
    }

    enum Image {
      case unknown
      case loading
      case available(UIImage)
      case missing
    }
  }
}

// MARK: - View Controller Lifecycle

extension GenreListController {
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.prefetchDataSource = self
    reload()
  }
}

// MARK: - Data Management

extension GenreListController {
  private func reload() {
    self.setupViewModel()
    if viewModel.isEmpty {
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
    if let genreIds = self.genreIds {
      viewModel = genreIds.flatMap { id in L10n.genreName(for: id).map { name in Genre(id: id, name: name) } }
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

  private func clearGenreImages() {
    self.viewModel.forEach { $0.image = .unknown }
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

extension GenreListController: UITableViewDataSourcePrefetching {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModel.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(GenreCell.self)
    cell.configure(for: viewModel[indexPath.row], genreImageProvider: genreImageProvider)
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
      if case Genre.Image.unknown = genre.image {
        genre.image = .loading
        DispatchQueue.global(qos: .background).async {
          let backdrop = self.genreImageProvider.genreImage(for: genre.id)
          DispatchQueue.main.async {
            if let backdropImage = backdrop {
              genre.image = .available(backdropImage)
              if let cell = tableView.cellForRow(at: indexPath) as? GenreCell {
                cell.configure(for: genre, genreImageProvider: self.genreImageProvider)
              }
            } else {
              genre.image = .missing
            }
          }
        }
      }
    }
  }
}

// MARK: - Genre Cell

class GenreCell: UITableViewCell {
  @IBOutlet private weak var backdropImageView: UIImageView!
  @IBOutlet private weak var genreNameLabel: UILabel!
  @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
  private var scrim: ScrimView!
  private var workItem: DispatchWorkItem?

  override func awakeFromNib() {
    super.awakeFromNib()
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

  fileprivate func configure(for genre: GenreListController.Genre, genreImageProvider: GenreImageProvider) {
    genreNameLabel.text = genre.name
    configureBackdrop(genre: genre, genreImageProvider: genreImageProvider)
  }

  private func configureBackdrop(genre: GenreListController.Genre, genreImageProvider: GenreImageProvider) {
    switch genre.image {
      case .unknown:
        configureBackdropForUnknownOrLoadingImageState()
        genre.image = .loading
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem {
          let backdrop = genreImageProvider.genreImage(for: genre.id)
          DispatchQueue.main.async {
            if let backdropImage = backdrop {
              genre.image = .available(backdropImage)
            } else {
              genre.image = .missing
            }
            if !(workItem?.isCancelled ?? true) {
              self.configureBackdrop(genre: genre, genreImageProvider: genreImageProvider)
            }
          }
        }
        self.workItem = workItem
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
      case .loading:
        configureBackdropForUnknownOrLoadingImageState()
      case let .available(genreImage):
        genreNameLabel.textColor = .white
        genreNameLabel.layer.shadowOpacity = 1.0
        backdropImageView.image = genreImage
        backdropImageView.contentMode = .scaleAspectFill
        scrim.isHidden = false
        self.activityIndicator.stopAnimating()
      case .missing:
        genreNameLabel.textColor = #colorLiteral(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        genreNameLabel.layer.shadowOpacity = 0.0
        backdropImageView.image = #imageLiteral(resourceName: "MissingGenreImage")
        backdropImageView.contentMode = .center
        backdropImageView.backgroundColor = .missingArtworkBackground
        scrim.isHidden = true
        self.activityIndicator.stopAnimating()
    }
  }

  private func configureBackdropForUnknownOrLoadingImageState() {
    genreNameLabel.textColor = #colorLiteral(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    genreNameLabel.layer.shadowOpacity = 0.0
    backdropImageView.image = nil
    backdropImageView.backgroundColor = .missingArtworkBackground
    scrim.isHidden = true
    activityIndicator.startAnimating()
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.workItem?.cancel()
    self.workItem = nil
    self.activityIndicator.stopAnimating()
  }
}
