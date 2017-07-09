import Foundation

struct TitleSortingStrategy: TableViewSortingStrategy {

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
      case .orderedSame: return left.year <= right.year
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
