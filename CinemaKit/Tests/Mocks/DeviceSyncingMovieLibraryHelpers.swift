@testable import CinemaKit
import CloudKit

extension DeviceSyncingMovieLibrary {
  static func makeForTesting(
      metadata: MovieLibraryMetadata = MovieLibraryMetadata(name: "Library"),
      modelController: MovieLibraryModelControllerMock = .load([]),
      tmdbPropertiesProvider: TmdbMoviePropertiesProvider = TmdbMoviePropertiesProviderMock.trap(),
      syncManager: SyncManager = SyncManagerMock()) -> DeviceSyncingMovieLibrary {
    return DeviceSyncingMovieLibrary(metadata: metadata,
                                     modelController: modelController,
                                     tmdbPropertiesProvider: tmdbPropertiesProvider,
                                     syncManager: syncManager)
  }
}
