import Foundation

enum SortDescriptor {
  case title, runtime, year

  var tableViewStrategy: TableViewSortingStrategy {
    switch self {
      case .title: return TitleSortingStrategy()
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

private struct TitleSortingStrategy: TableViewSortingStrategy {

  private let allSectionIndexTitles = ["#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
                                       "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

  func sectionIndexTitle(for item: MediaItem) -> String {
    let title = removeArticlesAtBeginning(from: item.title)
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
      case .orderedSame: fallthrough
      case .orderedAscending: return true
      case .orderedDescending: return false
    }
  }

  func itemSorting(left: MediaItem, right: MediaItem) -> Bool {
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
      let regex = try NSRegularExpression(pattern: "^(the|der|die|das) +",
                                          options: NSRegularExpression.Options.caseInsensitive)
      let range = NSRange(location: 0, length: str.characters.count)
      return regex.stringByReplacingMatches(in: str, range: range, withTemplate: "")
    } catch {
      return str
    }
  }

}

private struct RuntimeSortingStrategy: TableViewSortingStrategy {

  private let unknownSymbol = "?"

  func sectionIndexTitle(for item: MediaItem) -> String {
    guard let runtime = item.runtime else { return unknownSymbol }
    return String(runtime / 10 * 10)
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
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.minute]
        return formatter.string(from: runtime)!
    }
  }

  func sectionIndexTitleSorting(left: String, right: String) -> Bool {
    guard left != unknownSymbol else { return false }
    guard right != unknownSymbol else { return true }
    return Int(left)! <= Int(right)!
  }

  func itemSorting(left: MediaItem, right: MediaItem) -> Bool {
    guard let leftRuntime = left.runtime else { return false }
    guard let rightRuntime = right.runtime else { return true }
    return leftRuntime <= rightRuntime
  }
}

private struct YearSortingStrategy: TableViewSortingStrategy {

  private let unknownSymbol = "?"

  func sectionIndexTitle(for item: MediaItem) -> String {
    guard let releaseDate = item.releaseDate else { return unknownSymbol }
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

  func itemSorting(left: MediaItem, right: MediaItem) -> Bool {
    switch left.title.compare(right.title, options: [.diacriticInsensitive, .caseInsensitive]) {
      case .orderedSame: fallthrough
      case .orderedAscending: return true
      case .orderedDescending: return false
    }
  }
}
