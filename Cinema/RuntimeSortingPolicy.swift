import Foundation

struct RuntimeSortingPolicy: SortingPolicy {

  func sectionIndexTitle(for item: MediaItem) -> String {
    return String(item.runtime / 10 * 10)
  }

  func refineSectionIndexTitles(_ sections: [String]) -> [String] {
    let min = Int(sections.first!)!
    let max = Int(sections.last!)!
    if min == max {
      return sections
    } else {
      return Array(stride(from: min, through: max, by: 10)).map({ String($0) })
    }
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    let runtime = DateComponents(minute: Int(sectionIndexTitle)!)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.minute]
    return formatter.string(from: runtime)!
  }

  func sectionIndexTitleSorting(left: String, right: String) -> Bool {
    return Int(left)! <= Int(right)!
  }

  func itemSorting(left: MediaItem, right: MediaItem) -> Bool {
    return left.runtime <= right.runtime
  }
}
