import CinemaKit
import Dispatch
import Foundation
import UIKit

protocol LibraryContentCoordinatorDelegate: class {
  func libraryContentCoordinatorShowLibraryList(_ coordinator: LibraryContentCoordinator)
  func libraryContentCoordinatorDidDismiss(_ coordinator: LibraryContentCoordinator)
}

class LibraryContentCoordinator: AutoPresentableCoordinator {
  enum ContentSpecification {
    case all
    case allWith(GenreIdentifier)
  }

  private static let sortDescriptorKey = UserDefaultsKey<String>("MovieSortDescriptor")

  // coordinator stuff
  weak var delegate: LibraryContentCoordinatorDelegate?

  // other properties
  private let dependencies: AppDependencies
  private let userDefaults: UserDefaultsProtocol
  private let notificationCenter: NotificationCenter
  var library: MovieLibrary {
    willSet {
      library.delegates.remove(self)
    }
    didSet {
      setup()
    }
  }
  private let content: ContentSpecification
  var dismissWhenEmpty = false
  var showsLibrarySwitch = false {
    didSet {
      if showsLibrarySwitch {
        let button = UIBarButtonItem(image: #imageLiteral(resourceName: "SwitchLibrary"),
                                     style: .done,
                                     target: self,
                                     action: #selector(showLibraryListSheet))
        movieListController.navigationItem.leftBarButtonItem = button
      } else {
        movieListController.navigationItem.leftBarButtonItem = nil
      }
    }
  }

  // managed controllers
  private let navigationController: UINavigationController
  private let movieListController = UIStoryboard.movieList.instantiate(MovieListController.self)

  // child coordinators
  private var movieDetailsCoordinator: MovieDetailsCoordinator?
  private var editMovieCoordinator: EditMovieCoordinator?
  private var token: ObservationToken?

  init(for library: MovieLibrary,
       displaying content: ContentSpecification,
       navigationController: UINavigationController,
       dependencies: AppDependencies) {
    self.dependencies = dependencies
    self.userDefaults = dependencies.userDefaults
    self.notificationCenter = dependencies.notificationCenter
    self.library = library
    self.content = content
    self.navigationController = navigationController
    movieListController.delegate = self
    movieListController.posterProvider = MovieDbPosterProvider(dependencies.movieDb)
    if let rawSortDescriptor = userDefaults.get(for: LibraryContentCoordinator.sortDescriptorKey),
       let sortDescriptor = SortDescriptor(rawValue: rawSortDescriptor) {
      movieListController.sortDescriptor = sortDescriptor
    }
    self.token = userDefaults.observerValue(for: LibraryContentCoordinator.sortDescriptorKey) { [weak self] value in
      guard let `self` = self else { return }
      guard let rawSortDescriptor = value,
            let sortDescriptor = SortDescriptor(rawValue: rawSortDescriptor) else { return }
      DispatchQueue.main.async {
        if self.movieListController.sortDescriptor != sortDescriptor {
          self.movieListController.sortDescriptor = sortDescriptor
        }
      }
    }
    setup()
  }

  func presentRootViewController() {
    self.navigationController.pushViewController(movieListController, animated: true)
  }

  private func setup() {
    library.delegates.add(self)
    updateTitle()
    movieListController.listData = .loading
    if let editMovieCoordinator = editMovieCoordinator {
      editMovieCoordinator.rootViewController.dismiss(animated: true) {
        self.navigationController.popToRootViewController(animated: true)
      }
    } else if movieDetailsCoordinator != nil {
      navigationController.popToRootViewController(animated: true)
    }
    DispatchQueue.global(qos: .default).async {
      self.fetchListData()
    }
  }

  private func updateTitle() {
    switch content {
      case .all:
        movieListController.navigationItem.title = library.metadata.name
      case let .allWith(genreId):
        movieListController.navigationItem.title = L10n.genreName(for: genreId)!
    }
  }

  private func fetchListData() {
    switch content {
      case .all:
        library.fetchMovies(then: self.handleFetchedMovies)
      case let .allWith(genreId):
        library.fetchMovies(for: genreId, then: self.handleFetchedMovies)
    }
  }

  private func handleFetchedMovies(result: Result<[Movie], MovieLibraryError>) {
    switch result {
      case let .failure(error):
        switch error {
          case let .globalError(event):
            notificationCenter.post(event.notification)
          case .nonRecoverableError:
            DispatchQueue.main.async {
              self.movieListController.listData = .unavailable
            }
          case .tmdbDetailsCouldNotBeFetched, .movieDoesNotExist, .permissionFailure:
            fatalError("should not occur")
        }
      case let .success(movies):
        DispatchQueue.main.async {
          self.movieListController.listData = .available(movies)
        }
    }
  }
}

// MARK: - MovieListControllerDelegate

extension LibraryContentCoordinator: MovieListControllerDelegate {
  func movieListControllerShowSortDescriptorSheet(_ controller: MovieListController) {
    let sheet = TabularSheetController<SelectableLabelSheetItem>(cellConfig: SelectableLabelCellConfig())
    for descriptor in SortDescriptor.allCases {
      sheet.addSheetItem(SelectableLabelSheetItem(title: descriptor.localizedName,
                                                  showCheckmark: descriptor == controller.sortDescriptor) { _ in
        guard controller.sortDescriptor != descriptor else { return }
        controller.sortDescriptor = descriptor
        self.userDefaults.set(descriptor.rawValue, for: LibraryContentCoordinator.sortDescriptorKey)
      })
    }
    controller.present(sheet, animated: true)
  }

  func movieListController(_ controller: MovieListController, didSelect movie: Movie) {
    movieDetailsCoordinator = MovieDetailsCoordinator(for: movie, using: dependencies.movieDb)
    movieDetailsCoordinator!.delegate = self
    if library.metadata.currentUserCanModify {
      let editButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                       target: self,
                                       action: #selector(editButtonTapped))
      movieDetailsCoordinator!.rootViewController.navigationItem.rightBarButtonItem = editButton
    }
    self.navigationController.pushViewController(movieDetailsCoordinator!.rootViewController, animated: true)
  }

  @objc
  private func editButtonTapped() {
    guard let movie = self.movieDetailsCoordinator?.movie else {
      preconditionFailure("MovieDetailsCoordinator should present movie details")
    }
    editMovieCoordinator = EditMovieCoordinator(for: movie, in: library)
    editMovieCoordinator!.delegate = self
    self.navigationController.present(editMovieCoordinator!.rootViewController, animated: true)
  }

  func movieListControllerDidDismiss(_ controller: MovieListController) {
    self.delegate?.libraryContentCoordinatorDidDismiss(self)
  }
}

// MARK: - MovieDetailsCoordinatorDelegate

extension LibraryContentCoordinator: MovieDetailsCoordinatorDelegate {
  func movieDetailsCoordinatorDidDismiss(_ coordinator: MovieDetailsCoordinator) {
    self.movieDetailsCoordinator = nil
  }
}

// MARK: - EditMovieCoordinatorDelegate

extension LibraryContentCoordinator: EditMovieCoordinatorDelegate {
  func editMovieCoordinator(_ coordinator: EditMovieCoordinator,
                            didFinishEditingWith editResult: EditMovieCoordinator.EditResult) {
    switch editResult {
      case let .edited(editedMovie):
        guard let movieDetailsCoordinator = self.movieDetailsCoordinator else {
          preconditionFailure("MovieDetailsCoordinator should present movie details")
        }
        movieDetailsCoordinator.updateNonRemoteProperties(with: editedMovie)
        coordinator.rootViewController.dismiss(animated: true)
      case .deleted:
        coordinator.rootViewController.dismiss(animated: true) {
          self.navigationController.popViewController(animated: true)
          self.movieDetailsCoordinator = nil
        }
      case .canceled:
        coordinator.rootViewController.dismiss(animated: true)
    }
    self.editMovieCoordinator = nil
  }

  func editMovieCoordinator(_ coordinator: EditMovieCoordinator, didFailWith error: MovieLibraryError) {
    switch error {
      case let .globalError(event):
        notificationCenter.post(event.notification)
      case .permissionFailure:
        DispatchQueue.main.async {
          coordinator.rootViewController.presentPermissionFailureAlert {
            coordinator.rootViewController.dismiss(animated: true) {
              self.editMovieCoordinator = nil
            }
          }
        }
        self.notificationCenter.post(ApplicationWideEvent.shouldFetchChanges.notification)
      case .nonRecoverableError:
        coordinator.rootViewController.presentErrorAlert()
      case .tmdbDetailsCouldNotBeFetched, .movieDoesNotExist:
        fatalError("should not occur: \(error)")
    }
  }
}

// MARK: - Switching Libraries

extension LibraryContentCoordinator {
  @objc
  private func showLibraryListSheet() {
    self.delegate?.libraryContentCoordinatorShowLibraryList(self)
  }
}

// MARK: - Library Events

extension LibraryContentCoordinator: MovieLibraryDelegate {
  func libraryDidUpdateMetadata(_ library: MovieLibrary) {
    DispatchQueue.main.async {
      self.updateTitle()
      if self.movieDetailsCoordinator != nil {
        if library.metadata.currentUserCanModify &&
           self.movieDetailsCoordinator!.rootViewController.navigationItem.rightBarButtonItem == nil {
          let editButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                           target: self,
                                           action: #selector(self.editButtonTapped))
          self.movieDetailsCoordinator!.rootViewController.navigationItem.rightBarButtonItem = editButton
        } else if !library.metadata.currentUserCanModify &&
                  self.movieDetailsCoordinator!.rootViewController.navigationItem.rightBarButtonItem != nil {
          self.movieDetailsCoordinator!.rootViewController.navigationItem.rightBarButtonItem = nil
          if let editMovieCoordinator = self.editMovieCoordinator {
            if editMovieCoordinator.rootViewController.presentedViewController == nil {
              editMovieCoordinator.rootViewController.dismiss(animated: true) {
                self.editMovieCoordinator = nil
              }
            } else {
              // alert dismisses editMovieCoordinator
            }
          }
        }
      }
    }
  }

  func library(_ library: MovieLibrary, didUpdateMovies changeSet: ChangeSet<TmdbIdentifier, Movie>) {
    guard case var .available(listItems) = movieListController.listData else { return }

    // updated movies
    if !changeSet.modifications.isEmpty {
      for (id, movie) in changeSet.modifications {
        guard let index = listItems.index(where: { $0.tmdbID == id }) else { continue }
        listItems.remove(at: index)
        listItems.insert(movie, at: index)
      }
    }

    // new movies
    let newMovies: [Movie]
    switch content {
      case .all:
        newMovies = changeSet.insertions
      case let .allWith(genreId):
        newMovies = changeSet.insertions.filter { $0.genreIds.contains(genreId) }
    }
    listItems.append(contentsOf: newMovies)

    // removed movies
    if !changeSet.deletions.isEmpty {
      for (_, movie) in changeSet.deletions {
        guard let index = listItems.index(of: movie) else { continue }
        listItems.remove(at: index)
      }
    }
    DispatchQueue.main.async {
      if let movieDetailsCoordinator = self.movieDetailsCoordinator {
        if let updatedMovie = changeSet.modifications[movieDetailsCoordinator.movie.tmdbID] {
          movieDetailsCoordinator.updateNonRemoteProperties(with: updatedMovie)
          self.editMovieCoordinator?.movie = updatedMovie
        } else if changeSet.deletions[movieDetailsCoordinator.movie.tmdbID] != nil {
          if let editMovieCoordinator = self.editMovieCoordinator {
            editMovieCoordinator.rootViewController.dismiss(animated: true) {
              self.navigationController.popToViewController(self.movieListController, animated: true)
              self.movieDetailsCoordinator = nil
            }
            self.editMovieCoordinator = nil
          } else {
            self.navigationController.popToViewController(self.movieListController, animated: true)
            self.movieDetailsCoordinator = nil
          }
        }
      }

      // commit changes only when controller is not being dismissed anyway
      if listItems.isEmpty && self.dismissWhenEmpty {
        self.movieListController.onViewDidAppear = { [weak self] in
          guard let `self` = self else { return }
          self.navigationController.popViewController(animated: true)
        }
      } else {
        self.movieListController.listData = .available(listItems)
      }
    }
  }
}
