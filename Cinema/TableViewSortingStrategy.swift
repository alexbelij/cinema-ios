protocol TableViewSortingStrategy {

  func sectionIndexTitle(for item: MediaItem) -> String
  func refineSectionIndexTitles(_: [String]) -> [String]

  func sectionTitle(for sectionIndexTitle: String) -> String

  func sectionIndexTitleSorting(left: String, right: String) -> Bool
  func itemSorting(left: MediaItem, right: MediaItem) -> Bool

}

extension TableViewSortingStrategy {
  func refineSectionIndexTitles(_ sections: [String]) -> [String] {
    return sections
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    return sectionIndexTitle
  }
}
