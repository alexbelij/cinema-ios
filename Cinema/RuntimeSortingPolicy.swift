import Foundation

struct RuntimeSortingPolicy: SortingPolicy {

  func sectionIndexTitle(for item: MediaItem) -> String {
    return String(item.runtime / 10 * 10)
  }

  func completeSectionIndexTitles(_ sections: [String]) -> [String] {
    let min = Int(sections.first!)!
    let max = Int(sections.last!)!
    if min == max {
      return sections
    } else {
      return Array(stride(from: min, through: max, by: 10)).map({ String($0) })
    }
  }

  func sectionIndexTitleSorting(left: String, right: String) -> Bool {
    return Int(left)! <= Int(right)!
  }

  func itemSorting(left: MediaItem, right: MediaItem) -> Bool {
    return left.runtime <= right.runtime
  }
}
