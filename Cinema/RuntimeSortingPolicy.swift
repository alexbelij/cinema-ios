import Foundation

struct RuntimeSortingPolicy: SortingPolicy {

  private let unknownSymbol = "?"

  func sectionIndexTitle(for item: MediaItem) -> String {
    switch item.runtime {
      case -1: return unknownSymbol
      default: return String(item.runtime / 10 * 10)
    }
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
      return Array(stride(from: min, through: max, by: 10)).map({ String($0) })
    }
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    switch sectionIndexTitle {
      case unknownSymbol: return NSLocalizedString("sort.by.runtime.unknownHeader", comment: "")
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
    return left.runtime <= right.runtime
  }
}
