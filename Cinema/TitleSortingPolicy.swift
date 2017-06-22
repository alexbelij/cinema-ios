import Foundation

struct TitleSortingPolicy: SortingPolicy {

  private let allSectionIndexTitles = ["#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
                                       "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

  func sectionIndexTitle(for item: MediaItem) -> String {
    let firstCharacter = String(item.title[item.title.startIndex])
    let folded = firstCharacter.folding(options: .diacriticInsensitive, locale: Locale.current)
    if folded.rangeOfCharacter(from: .letters) != nil {
      return folded.uppercased()
    } else {
      return "#"
    }
  }

  func completeSectionIndexTitles(_ sections: [String]) -> [String] {
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
    switch left.title.compare(right.title, options: [.diacriticInsensitive, .caseInsensitive]) {
      case .orderedSame: return left.year <= right.year
      case .orderedAscending: return true
      case .orderedDescending: return false
    }
  }

}
