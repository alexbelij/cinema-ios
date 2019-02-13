import CinemaKit

protocol MovieListItemGrouping {
  var sorting: MovieListItemSorting { get }

  func sectionIndexTitle(for movie: Movie) -> String
  func areSectionIndexTitlesInIncreasingOrder(left: String, right: String) -> Bool
  func refinedSectionIndexTitles(_ sectionIndexTitles: [String]) -> [String]
  func sectionTitle(for sectionIndexTitle: String) -> String
}

extension MovieListItemGrouping {
  func refineSectionIndexTitles(_ sectionIndexTitles: [String]) -> [String] {
    return sectionIndexTitles
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    return sectionIndexTitle
  }
}

struct FirstCharacterOfTitleGrouping: MovieListItemGrouping {
  private static let allSectionIndexTitles = ["#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
                                              "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

  let sorting: MovieListItemSorting = TitleSorting()

  func sectionIndexTitle(for movie: Movie) -> String {
    let title = movie.title.removingIgnoredPrefixes()
    let firstCharacter = String(title[title.startIndex])
    let folded = firstCharacter.folding(options: .diacriticInsensitive, locale: Locale.current)
    if folded.rangeOfCharacter(from: .letters) == nil {
      return "#"
    } else {
      return folded.uppercased()
    }
  }

  func areSectionIndexTitlesInIncreasingOrder(left: String, right: String) -> Bool {
    switch left.compare(right) {
      case .orderedSame, .orderedAscending: return true
      case .orderedDescending: return false
    }
  }

  func refinedSectionIndexTitles(_ sectionIndexTitles: [String]) -> [String] {
    return FirstCharacterOfTitleGrouping.allSectionIndexTitles
  }
}

struct RuntimeGrouping: MovieListItemGrouping {
  private static let minutesFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.minute]
    return formatter
  }()

  private let unknownSymbol = "?"

  let sorting: MovieListItemSorting = RuntimeSorting()

  func sectionIndexTitle(for movie: Movie) -> String {
    guard let runtime = movie.runtime else { return unknownSymbol }
    let minutes = Int(runtime.converted(to: UnitDuration.minutes).value)
    return String(minutes / 10 * 10)
  }

  func areSectionIndexTitlesInIncreasingOrder(left: String, right: String) -> Bool {
    guard left != unknownSymbol else { return false }
    guard right != unknownSymbol else { return true }
    return Int(left)! <= Int(right)!
  }

  func refinedSectionIndexTitles(_ sectionIndexTitles: [String]) -> [String] {
    guard !sectionIndexTitles.isEmpty && sectionIndexTitles != [unknownSymbol] else { return [] }
    let containsUnknownElements = sectionIndexTitles.last! == unknownSymbol
    let min = Int(sectionIndexTitles.first!)!
    let maxIndex = sectionIndexTitles.count - 1 - (containsUnknownElements ? 1 : 0)
    let max = Int(sectionIndexTitles[maxIndex])!
    if min == max {
      return Array(sectionIndexTitles.dropLast())
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
        return RuntimeGrouping.minutesFormatter.string(from: runtime)!
    }
  }
}

struct ReleaseDateGrouping: MovieListItemGrouping {
  private let unknownSymbol = "?"
  private let currentYear = Calendar.current.component(.year, from: Date())
  private let numberOfStandaloneYears = 10

  let sorting: MovieListItemSorting = TitleSorting()

  func sectionIndexTitle(for movie: Movie) -> String {
    guard let releaseDate = movie.releaseDate else { return unknownSymbol }
    let year = Calendar.current.component(.year, from: releaseDate)
    if year < currentYear - numberOfStandaloneYears {
      return String(year / 10 * 10)
    } else {
      return String(year)
    }
  }

  func areSectionIndexTitlesInIncreasingOrder(left: String, right: String) -> Bool {
    guard left != unknownSymbol else { return false }
    guard right != unknownSymbol else { return true }
    return Int(left)! >= Int(right)!
  }

  func refinedSectionIndexTitles(_ sectionIndexTitles: [String]) -> [String] {
    if let index = sectionIndexTitles.index(of: unknownSymbol) {
      var sectionIndexTitles = sectionIndexTitles
      sectionIndexTitles.remove(at: index)
      return sectionIndexTitles
    }
    return sectionIndexTitles
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    switch sectionIndexTitle {
      case unknownSymbol:
        return NSLocalizedString("sort.by.year.unknownHeader", comment: "")
      default:
        let year = Int(sectionIndexTitle)!
        let thresholdYear = currentYear - numberOfStandaloneYears
        if year < thresholdYear {
          return "\(year) - \(min(thresholdYear, year + 10) - 1)"
        } else {
          return sectionIndexTitle
        }
    }
  }
}
