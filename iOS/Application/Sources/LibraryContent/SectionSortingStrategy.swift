import CinemaKit
protocol SectionSortingStrategy {
  func sectionIndexTitle(for movie: Movie) -> String
  func refineSectionIndexTitles(_: [String]) -> [String]

  func sectionTitle(for sectionIndexTitle: String) -> String

  func sectionIndexTitleSorting(left: String, right: String) -> Bool
  func movieSorting(left: Movie, right: Movie) -> Bool
}

extension SectionSortingStrategy {
  func refineSectionIndexTitles(_ sections: [String]) -> [String] {
    return sections
  }

  func sectionTitle(for sectionIndexTitle: String) -> String {
    return sectionIndexTitle
  }
}
