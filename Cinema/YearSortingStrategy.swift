struct YearSortingStrategy: TableViewSortingStrategy {

  func sectionIndexTitle(for item: MediaItem) -> String {
    if item.year < 2010 {
      return String(item.year / 10 * 10)
    } else {
      return String(item.year)
    }
  }

  func sectionIndexTitleSorting(left: String, right: String) -> Bool {
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
