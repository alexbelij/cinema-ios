import Foundation

struct TitleSortingPolicy: SortingPolicy {

  func sectionTitle(for item: MediaItem) -> String {
    let firstCharacter = String(item.title[item.title.startIndex])
    if firstCharacter.rangeOfCharacter(from: .letters) != nil {
      return firstCharacter.uppercased()
    } else {
      return "#"
    }
  }

  func sectionTitleSorting(left: String, right: String) -> Bool {
    return left < right
  }

  func itemSorting(left: MediaItem, right: MediaItem) -> Bool {
    if left.title != right.title {
      return left.title < right.title
    } else {
      return left.year < right.year
    }
  }

}
