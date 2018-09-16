@testable import CinemaKit
import CloudKit

enum MovieBuilder {
  static func makeMovie(tmdbID: Int,
                        inLibraryWithID libraryID: CKRecord.ID,
                        title: String = "Movie",
                        genreId: Int = 1) -> Movie {
    let cloudProperties = Movie.CloudProperties(tmdbID: TmdbIdentifier(rawValue: tmdbID),
                                                libraryID: libraryID,
                                                title: title,
                                                subtitle: nil,
                                                diskType: .bluRay)
    let tmdbProperties = Movie.TmdbProperties(genreIds: [GenreIdentifier(rawValue: genreId)])
    return Movie(cloudProperties, tmdbProperties)
  }
}
