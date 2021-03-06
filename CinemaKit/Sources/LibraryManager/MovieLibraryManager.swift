import CloudKit
import Foundation
import UIKit

public protocol MovieLibraryManagerDelegate: class {
  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didUpdateLibraries changeSet: ChangeSet<CKRecord.ID, MovieLibrary>)

  // sharing
  func libraryManager(_ libraryManager: MovieLibraryManager, willAcceptSharedLibraryWith title: String)
  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didFailToAcceptSharedLibraryWith title: String,
                      reason: AcceptShareFailureReason)
  func libraryManager(_ libraryManager: MovieLibraryManager,
                      didAcceptSharedLibrary library: MovieLibrary,
                      with title: String)
}

public enum CloudSharingControllerParameters {
  case hasBeenShared(CKShare, CKContainer, CloudSharingControllerCallback)
  case hasNotBeenShared((@escaping (CKShare?, CKContainer?, Error?) -> Void) -> Void, CloudSharingControllerCallback)
}

public protocol CloudSharingControllerCallback {
  func didStopSharingLibrary(with metadata: MovieLibraryMetadata)
}

public protocol MovieLibraryManager: class {
  var delegates: MulticastDelegate<MovieLibraryManagerDelegate> { get }

  // accessing library content
  func fetchLibraries(then completion: @escaping (Result<[MovieLibrary], MovieLibraryManagerError>) -> Void)

  // managing library content
  func addLibrary(with metadata: MovieLibraryMetadata,
                  then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void)
  func updateLibrary(with metadata: MovieLibraryMetadata,
                     then completion: @escaping (Result<MovieLibrary, MovieLibraryManagerError>) -> Void)
  func removeLibrary(with id: CKRecord.ID, then completion: @escaping (Result<Void, MovieLibraryManagerError>) -> Void)

  func fetchChanges(then completion: @escaping (Result<Bool, MovieLibraryManagerError>) -> Void)

  // sharing
  func prepareCloudSharingController(
      forLibraryWith metadata: MovieLibraryMetadata,
      then completion: @escaping (Result<CloudSharingControllerParameters, MovieLibraryManagerError>) -> Void)
  func acceptCloudKitShare(with shareMetadata: CKShare.Metadata)
}

public enum MovieLibraryManagerError: Error {
  case globalError(ApplicationWideEvent)
  case nonRecoverableError
  case libraryDoesNotExist
  case permissionFailure
}

public enum AcceptShareFailureReason {
  case alreadyAccepted
  case currentUserIsOwner
  case error
}

enum AcceptShareResult {
  case accepted
  case aborted(AcceptShareFailureReason)
}

protocol InternalMovieLibraryManager: MovieLibraryManager {
  func acceptCloudKitShare(with shareMetadata: CKShareMetadataProtocol,
                           then completion: @escaping (Result<AcceptShareResult, MovieLibraryManagerError>) -> Void)
  func migrateLegacyLibrary(with name: String, at url: URL, then completion: @escaping (Bool) -> Void)
}

extension InternalMovieLibraryManager {
  func acceptCloudKitShare(with shareMetadata: CKShare.Metadata) {
    acceptCloudKitShare(with: shareMetadata) { _ in }
  }
}

extension CloudKitError {
  var asMovieLibraryManagerError: MovieLibraryManagerError {
    switch self {
      case .itemNoLongerExists:
        return .libraryDoesNotExist
      case .notAuthenticated:
        return .globalError(.notAuthenticated)
      case .userDeletedZone:
        return .globalError(.userDeletedZone)
      case .permissionFailure:
        return .permissionFailure
      case .nonRecoverableError:
        return .nonRecoverableError
      case .conflict, .zoneNotFound:
        fatalError("\(self) can not be expressed as MovieLibraryManagerError")
    }
  }
}
