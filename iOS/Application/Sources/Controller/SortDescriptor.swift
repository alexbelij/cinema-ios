import CinemaKit
import Foundation

enum SortDescriptor {
  case title, runtime, year

  func makeTableViewStrategy() -> SectionSortingStrategy {
    switch self {
      case .title:
        guard let path = Bundle.main.path(forResource: "SortPrefixes", ofType: "plist"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let prefixes = try? PropertyListDecoder().decode([String].self, from: data) else {
          fatalError("could not load sort prefixes")
        }
        return TitleSortingStrategy(ignoredPrefixes: prefixes)
      case .runtime: return RuntimeSortingStrategy()
      case .year: return YearSortingStrategy()
    }
  }

  var localizedName: String {
    switch self {
      case .title: return NSLocalizedString("sort.by.title", comment: "")
      case .runtime: return NSLocalizedString("sort.by.runtime", comment: "")
      case .year: return NSLocalizedString("sort.by.year", comment: "")
    }
  }
}

private struct TitleSortingStrategy: SectionSortingStrategy {

  private let allSectionIndexTitles = ["#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
                                       "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
  private let ignoredPrefixes: [String]

  init(ignoredPrefixes: [String]) {
    self.ignoredPrefixes = ignoredPrefixes
  }

  func sectionIndexTitle(for movie: Movie) -> String {
    let title = removeArticlesAtBeginning(from: movie.title)
    let firstCharacter = String(title[title.startIndex])
    let folded = firstCharacter.folding(options: .diacriticInsensitive, locale: Locale.current)
    if folded.rangeOfCharacter(from: .letters) != nil {
      return folded.uppercased()
    } else {
      return "#"
    }
  }

  func refineSectionIndexTitles(_ sections: [String]) -> [String] {
    return allSectionIndexTitles
  }

  func sectionIndexTitleSorting(left: String, right: String) -> Bool {
    switch left.compare(right) {
      case .orderedSame, .orderedAscending: return true
      case .orderedDescending: return false
    }
  }

  func movieSorting(left: Movie, right: Movie) -> Bool {
    let title1 = removeArticlesAtBeginning(from: left.title)
    let title2 = removeArticlesAtBeginning(from: right.title)
    switch title1.compare(title2, options: [.diacriticInsensitive, .caseInsensitive]) {
      case .orderedSame:
        guard let leftDate = left.releaseDate else { return false }
        guard let rightDate = right.releaseDate else { return true }
        return leftDate <= rightDate
      case .orderedAscending: return true
      case .orderedDescending: return false
    }
  }

  private func removeArticlesAtBeginning(from str: String) -> String {
    do {
      let regex = try NSRegularExpression(pattern: "^(\(ignoredPrefixes.joined(separator: "|")))",
                                          options: NSRegularExpression.Options.caseInsensitive)
      let range = NSRange(location: 0, length: str.count)
      return regex.stringByReplacingMatches(in: str, range: range, withTemplate: "")
    } catch {
      return str
    }
  }

}

private struct RuntimeSortingStrategy: SectionSortingStrategy {

  private static let minutesFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.minute]
    return formatter
  }()

  private let unknownSymbol = "?"

  func sectionIndexTitle(for movie: Movie) -> String {
    guard let runtime = movie.runtime else { return unknownSymbol }
    let minutes = Int(runtime.converted(to: UnitDuration.minutes).value)
    return String(minutes / 10 * 10)
  }

  func refineSectionIndexTitles(_ sections: [String]) -> [String] {
    guard !sections.isEmpty && sections != [unknownSymbol] else { return [] }
    let containsUnknownElements = sections.last! == unknownSymbol
    let min = Int(sections.first!)!
    let maxIndex = sections.count - 1 - (containsUnknownElements ? 1 : 0)
    let max = Int(sections[maxIndex])!
    if min == max {
      return Array(sections.dropLast())
    } else {
      return Array(stride(from: min, through: max, by: 10)).map { String($0) }
    }
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    switch sectionIndexTitle {
      case unknownSymbol: return NSLocalizedString("sort.by.runtime.unknownHeader", comment: "")
      case "0": return NSLocalizedString("sort.by.runtime.lessThanTenMinutes", comment: "")
      default:
        let runtime = DateComponents(minute: Int(sectionIndexTitle)!)
        return RuntimeSortingStrategy.minutesFormatter.string(from: runtime)!
    }
  }

  func sectionIndexTitleSorting(left: String, right: String) -> Bool {
    guard left != unknownSymbol else { return false }
    guard right != unknownSymbol else { return true }
    return Int(left)! <= Int(right)!
  }

  func movieSorting(left: Movie, right: Movie) -> Bool {
    guard let leftRuntime = left.runtime else { return false }
    guard let rightRuntime = right.runtime else { return true }
    return leftRuntime <= rightRuntime
  }
}

private struct YearSortingStrategy: SectionSortingStrategy {

  private let unknownSymbol = "?"

  func sectionIndexTitle(for movie: Movie) -> String {
    guard let releaseDate = movie.releaseDate else { return unknownSymbol }
    let year = Calendar.current.component(.year, from: releaseDate)
    if year < 2010 {
      return String(year / 10 * 10)
    } else {
      return String(year)
    }
  }

  func refineSectionIndexTitles(_ titles: [String]) -> [String] {
    if let index = titles.index(of: unknownSymbol) {
      var titles = titles
      titles.remove(at: index)
      return titles
    }
    return titles
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    switch sectionIndexTitle {
      case unknownSymbol:
        return NSLocalizedString("sort.by.year.unknownHeader", comment: "")
      default:
        return sectionIndexTitle
    }
  }

  func sectionIndexTitleSorting(left: String, right: String) -> Bool {
    guard left != unknownSymbol else { return false }
    guard right != unknownSymbol else { return true }
    return Int(left)! >= Int(right)!
  }

  func movieSorting(left: Movie, right: Movie) -> Bool {
    switch left.title.compare(right.title, options: [.diacriticInsensitive, .caseInsensitive]) {
      case .orderedSame, .orderedAscending: return true
      case .orderedDescending: return false
    }
  }
}
