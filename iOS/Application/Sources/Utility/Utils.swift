import CinemaKit
import UIKit

// MARK: - Other Extensions

extension UIStoryboard {
  static var movieList = UIStoryboard(name: "MovieList", bundle: nil)
  static var searchTmdb = UIStoryboard(name: "SearchTmdb", bundle: nil)
  static var popularMovies = UIStoryboard(name: "PopularMovies", bundle: nil)
  static var editMovie = UIStoryboard(name: "EditMovie", bundle: nil)
  static var genreList = UIStoryboard(name: "GenreList", bundle: nil)
  static var maintenance = UIStoryboard(name: "Maintenance", bundle: nil)
  static var libraryList = UIStoryboard(name: "LibraryList", bundle: nil)

  func instantiate<ViewController: UIViewController>(_ viewController: ViewController.Type) -> ViewController {
    let identifier = String(describing: viewController)
    guard let controller = instantiateViewController(withIdentifier: identifier)
        as? ViewController else {
      fatalError("could not instantiate view controller with identifier \(identifier) ")
    }
    return controller
  }
}

extension UIColor {
  // swiftlint:disable object_literal
  static let disabledControlText = UIColor(white: 0.58, alpha: 1.0)
  static let secondaryText = UIColor(white: 0.5, alpha: 1.0)
  static let destructive = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
  static let posterBorder = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2)
  static let dimBackground = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
  static let missingArtworkBackground = UIColor(white: 0.88, alpha: 1.0)
  // swiftlint:enable object_literal
}

extension String {
  var nilIfEmptyString: String? {
    return self.isEmpty ? nil : self
  }
}

extension UITableView {
  func reloadRowWithoutAnimation(at indexPath: IndexPath) {
    UIView.performWithoutAnimation {
      reloadRows(at: [indexPath], with: .none)
    }
  }
}

extension UIViewController {
  func presentErrorAlert() {
    let alert = UIAlertController(title: NSLocalizedString("error.genericError", comment: ""),
                                  message: NSLocalizedString("error.tryAgain", comment: ""),
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
    present(alert, animated: true)
  }

  func presentPermissionFailureAlert(handler: @escaping () -> Void) {
    let alert = UIAlertController(title: NSLocalizedString("error.permissionFailure", comment: ""),
                                  message: nil,
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default) { _ in
      handler()
    })
    present(alert, animated: true)
  }
}

enum ImageState {
  case unknown
  case loading
  case available(UIImage)
  case unavailable
}

protocol PosterHaving: class {
  var tmdbID: TmdbIdentifier { get }
  var poster: ImageState { get set }
}

func fetchPoster(for model: PosterHaving,
                 using posterProvider: PosterProvider,
                 size: PosterSize,
                 purpose: PosterPurpose,
                 then completion: @escaping () -> Void) {
  let poster = posterProvider.poster(for: model.tmdbID, size: size, purpose: purpose)
  DispatchQueue.main.async {
    if let posterImage = poster {
      model.poster = .available(posterImage)
    } else {
      model.poster = .unavailable
    }
    completion()
  }
}

enum StandardSortDescriptors {
  static let byLibraryName: (MovieLibrary, MovieLibrary) -> Bool = { library1, library2 in
    return byMetadataName(library1.metadata, library2.metadata)
  }

  static let byMetadataName: (MovieLibraryMetadata, MovieLibraryMetadata) -> Bool = { metadata1, metadata2 in
    return byName(metadata1.name, metadata2.name)
  }

  static let byName: (String, String) -> Bool = { string1, string2 in
    return string1.compare(string2, options: [.diacriticInsensitive, .caseInsensitive]) == .orderedAscending
  }
}
