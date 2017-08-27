import UIKit.UIImage

protocol MovieDbClient {

  func tryConnect()

  var storeFront: MovieDbStoreFront { get set }

  var language: MovieDbLanguage? { get set }

  var isConnected: Bool { get }

  func poster(for id: Int, size: PosterSize) -> UIKit.UIImage?

  func overview(for id: Int) -> String?

  func certification(for id: Int) -> String?

  func genreIds(for id: Int) -> [Int]

  func searchMovies(searchText: String) -> [PartialMediaItem]

  func runtime(for id: Int) -> Int?

  func popularMovies() -> PagingSequence<PartialMediaItem>

}

enum MovieDbStoreFront {
  case germany

  var language: String {
    switch self {
      case .germany: return "de"
    }
  }

  var country: String {
    switch self {
      case .germany: return "DE"
    }
  }
}

enum MovieDbLanguage: String {
  case en, de
}

public enum PosterSize: String {
  case w92, w154, w185, w342, w500, w780, original

  init(minWidth: Int, scaleFactor: CGFloat = UIScreen.main.scale) {
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

struct PagingSequence<PageElement>: Sequence, IteratorProtocol {
  typealias Element = PageElement

  private let pageGenerator: (Int) -> AnyIterator<PageElement>?

  private var nextPage = 1
  private var pageElementIterator: AnyIterator<PageElement>?

  init<S>(pageGenerator: @escaping (Int) -> S?) where S: Sequence, S.Iterator.Element == PageElement {
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

  mutating func next() -> PageElement? {
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
