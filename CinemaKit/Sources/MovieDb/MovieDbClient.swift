import Foundation
import UIKit

public protocol MovieDbClient {

  var language: MovieDbLanguage { get set }

  var country: MovieDbCountry { get set }

  func poster(for id: TmdbIdentifier, size: PosterSize, purpose: PosterPurpose) -> UIImage?

  func backdrop(for id: TmdbIdentifier, size: BackdropSize) -> UIImage?

  func overview(for id: TmdbIdentifier) -> String?

  func certification(for id: TmdbIdentifier) -> String?

  func genreIds(for id: TmdbIdentifier) -> [GenreIdentifier]

  func searchMovies(searchText: String) -> [PartialMediaItem]

  func runtime(for id: TmdbIdentifier) -> Measurement<UnitDuration>?

  func popularMovies() -> PagingSequence<PartialMediaItem>

  func releaseDate(for id: TmdbIdentifier) -> Date?

}

public enum PosterPurpose {
  case list
  case details
  case searchResult
  case popularMovies
  case libraryUpdate
}

public enum MovieDbCountry: String {
  case germany = "DE"
  case unitedStates = "US"
}

public enum MovieDbLanguage: String {
  // swiftlint:disable identifier_name
  case en
  case de
  // swiftlint:enable identifier_name
}

public enum PosterSize: String {
  case w92, w154, w185, w342, w500, w780, original

  public init(minWidth: Int, scaleFactor: CGFloat = UIScreen.main.scale) {
    switch minWidth * Int(scaleFactor) {
      case 0...92:    self =  .w92
      case 93...154:  self = .w154
      case 155...185: self = .w185
      case 186...342: self = .w342
      case 343...500: self = .w500
      default:        self = .w780
    }
  }
}

public enum BackdropSize: String {
  case w300, w780, w1280, original

  public init(minWidth: Int, scaleFactor: CGFloat = UIScreen.main.scale) {
    switch minWidth * Int(scaleFactor) {
      case 0...300:    self =  .w300
      case 301...780:  self =  .w780
      case 781...1280: self = .w1280
      default:         self = .w1280
    }
  }
}

public struct PagingSequence<PageElement>: Sequence, IteratorProtocol {
  public typealias Element = PageElement

  private let pageGenerator: (Int) -> AnyIterator<PageElement>?

  private var nextPage = 1
  private var pageElementIterator: AnyIterator<PageElement>?

  public init<S>(pageGenerator: @escaping (Int) -> S?) where S: Sequence, S.Iterator.Element == PageElement {
    self.pageGenerator = { page in
      guard let generatedPage = pageGenerator(page) else { return nil }
      return AnyIterator<PageElement>(generatedPage.makeIterator())
    }
  }

  private mutating func nextPageElementIterator() -> AnyIterator<PageElement>? {
    guard let pageElementIterator = pageGenerator(nextPage) else { return nil }
    defer { self.nextPage += 1 }
    return AnyIterator { pageElementIterator.next() }
  }

  public mutating func next() -> PageElement? {
    if pageElementIterator == nil {
      pageElementIterator = nextPageElementIterator()
    }
    guard let iterator = pageElementIterator else { return nil }
    guard let element = iterator.next() else {
      pageElementIterator = nil
      return next()
    }
    return element
  }
}
