import Foundation

protocol SortingPolicy {

  func sectionTitle(for item: MediaItem) -> String

  func sectionTitleSorting(left: String, right: String) -> Bool
  func itemSorting(left: MediaItem, right: MediaItem) -> Bool

}
