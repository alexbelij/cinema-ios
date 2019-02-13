import CinemaKit

class MovieListDataSource {
  private struct Section {
    let indexTitle: String?
    let title: String?
    let rows: [MovieListController.ListItem]?

    // standard section
    init(indexTitle: String, title: String, rows: [MovieListController.ListItem]) {
      self.indexTitle = indexTitle
      self.title = title
      self.rows = rows
    }

    // section index is shown, but no corresponding data
    init(indexTitle: String) {
      self.indexTitle = indexTitle
      self.title = nil
      self.rows = nil
    }

    // appended at the end
    init(title: String, rows: [MovieListController.ListItem]) {
      self.indexTitle = nil
      self.title = title
      self.rows = rows
    }
  }

  private let sections: [Section]
  private let indexPaths: [TmdbIdentifier: IndexPath]
  let isEmpty: Bool

  init(_ movies: [Movie], sortingStrategy: SectionSortingStrategy) {
    var indexPaths = [TmdbIdentifier: IndexPath]()
    var sections = [Section]()
    let sectionData: [String: [Movie]] = Dictionary(grouping: movies) { sortingStrategy.sectionIndexTitle(for: $0) }
    let existingSectionIndexTitles = Array(sectionData.keys).sorted(by: sortingStrategy.sectionIndexTitleSorting)
    let refinedSectionIndexTitles = sortingStrategy.refineSectionIndexTitles(existingSectionIndexTitles)
    for sectionIndex in refinedSectionIndexTitles.startIndex..<refinedSectionIndexTitles.endIndex {
      let indexTitle = refinedSectionIndexTitles[sectionIndex]
      if existingSectionIndexTitles.contains(indexTitle) {
        let rows: [MovieListController.ListItem] = sectionData[indexTitle]!.sorted(by: sortingStrategy.movieSorting)
                                                                           .map(MovieListController.ListItem.init)
        for rowIndex in rows.startIndex..<rows.endIndex {
          indexPaths[rows[rowIndex].movie.tmdbID] = IndexPath(row: rowIndex, section: sectionIndex)
        }
        sections.append(Section(indexTitle: indexTitle,
                                title: sortingStrategy.sectionTitle(for: indexTitle),
                                rows: rows))
      } else {
        sections.append(Section(indexTitle: indexTitle))
      }
    }
    let additionalIndexTitles = Set(existingSectionIndexTitles).subtracting(Set(refinedSectionIndexTitles))
    for indexTitle in additionalIndexTitles {
      let rows = sectionData[indexTitle]!.sorted(by: sortingStrategy.movieSorting)
                                         .map(MovieListController.ListItem.init)
      let sectionIndex = sections.count
      for rowIndex in rows.startIndex..<rows.endIndex {
        indexPaths[rows[rowIndex].movie.tmdbID] = IndexPath(row: rowIndex, section: sectionIndex)
      }
      sections.append(Section(title: sortingStrategy.sectionTitle(for: indexTitle), rows: rows))
    }
    self.sections = sections
    self.indexPaths = indexPaths
    isEmpty = movies.isEmpty
  }

  func item(at indexPath: IndexPath) -> MovieListController.ListItem {
    guard let item = sections[indexPath.section].rows?[indexPath.row] else {
      fatalError("accessing invalid row \(indexPath.row) in section \(indexPath)")
    }
    return item
  }

  func indexPath(for item: MovieListController.ListItem) -> IndexPath? {
    return indexPaths[item.movie.tmdbID]
  }

  var numberOfSections: Int {
    return sections.count
  }

  func numberOfRowsInSection(_ section: Int) -> Int {
    guard let rows = sections[section].rows else { return 0 }
    return rows.count
  }

  func titleForHeaderInSection(_ section: Int) -> String? {
    guard let title = sections[section].title else { return nil }
    return title
  }

  lazy var sectionIndexTitles: [String]? = {
    let titles = sections.compactMap { $0.indexTitle }
    return titles.isEmpty ? nil : titles
  }()

  func sectionForSectionIndexTitle(_ title: String, at index: Int) -> Int {
    return sections[index].rows == nil ? -1 : index
  }

  func filtered(by filter: (Movie) -> Bool) -> [MovieListController.ListItem] {
    let allItems: [MovieListController.ListItem] = sections.flatMap { $0.rows ?? [] }
    return allItems.filter { filter($0.movie) }
  }
}
