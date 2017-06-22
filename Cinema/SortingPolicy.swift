import Foundation

protocol SortingPolicy {

  func sectionTitle(for item: MediaItem) -> String
  func completeSectionIndexTitles(_: [String]) -> [String]

  func sectionTitleSorting(left: String, right: String) -> Bool
  func itemSorting(left: MediaItem, right: MediaItem) -> Bool

}

extension SortingPolicy {
  func completeSectionIndexTitles(_ sections: [String]) -> [String] {
    return sections
  }
}
