struct YearSortingPolicy: SortingPolicy {

  func sectionTitle(for item: MediaItem) -> String {
    if item.year < 2010 {
      return String(item.year / 10 * 10)
    } else {
      return String(item.year)
    }
  }

  func sectionTitleSorting(left: String, right: String) -> Bool {
    return Int(left)! >= Int(right)!
  }

  func itemSorting(left: MediaItem, right: MediaItem) -> Bool {
    return left.title < right.title
  }
}
