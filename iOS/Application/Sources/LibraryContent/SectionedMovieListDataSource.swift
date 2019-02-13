import CinemaKit
import UIKit

class SectionedMovieListDataSource {
  fileprivate struct Section {
    let indexTitle: String?
    let title: String?
    let dataSource: SimpleMovieListDataSource?

    // standard section
    init(indexTitle: String, title: String, dataSource: SimpleMovieListDataSource) {
      self.indexTitle = indexTitle
      self.title = title
      self.dataSource = dataSource
    }

    // section index is shown, but no corresponding data
    init(indexTitle: String) {
      self.indexTitle = indexTitle
      self.title = nil
      self.dataSource = nil
    }

    // appended at the end
    init(title: String, dataSource: SimpleMovieListDataSource) {
      self.indexTitle = nil
      self.title = title
      self.dataSource = dataSource
    }
  }

  private var sections: [Section]
  private(set) var sectionIndexTitles: [String]?
  private var sectionIndexBySectionIndexTitle: [String: Int]
  private let grouping: MovieListItemGrouping

  init(for listItems: [MovieListController.ListItem], groupingBy grouping: MovieListItemGrouping) {
    self.sectionIndexBySectionIndexTitle = [:]
    self.grouping = grouping
    var sections = [Section]()
    let sectionData = Dictionary(grouping: listItems) { grouping.sectionIndexTitle(for: $0.movie) }
    let existingSectionIndexTitles = Array(sectionData.keys)
        .sorted(by: grouping.areSectionIndexTitlesInIncreasingOrder)
    let refinedSectionIndexTitles = grouping.refinedSectionIndexTitles(existingSectionIndexTitles)

    // map every section index title to one section
    for sectionIndex in refinedSectionIndexTitles.startIndex..<refinedSectionIndexTitles.endIndex {
      let sectionIndexTitle = refinedSectionIndexTitles[sectionIndex]
      if existingSectionIndexTitles.contains(sectionIndexTitle) {
        let dataSource = SimpleMovieListDataSource(listItems: sectionData[sectionIndexTitle]!,
                                                   sortBy: grouping.sorting)
        sections.append(Section(indexTitle: sectionIndexTitle,
                                title: grouping.sectionTitle(for: sectionIndexTitle),
                                dataSource: dataSource))
      } else {
        sections.append(Section(indexTitle: sectionIndexTitle))
      }
      sectionIndexBySectionIndexTitle[sectionIndexTitle] = sectionIndex
    }

    // there may be section index titles that were excluded while refining
    let additionalIndexTitles = Set(existingSectionIndexTitles).subtracting(Set(refinedSectionIndexTitles))
    var sectionIndex = refinedSectionIndexTitles.endIndex
    for sectionIndexTitle in additionalIndexTitles {
      let dataSource = SimpleMovieListDataSource(listItems: sectionData[sectionIndexTitle]!,
                                                 sortBy: grouping.sorting)
      sections.append(Section(title: grouping.sectionTitle(for: sectionIndexTitle),
                              dataSource: dataSource))
      sectionIndexBySectionIndexTitle[sectionIndexTitle] = sectionIndex
      sectionIndex += 1
    }
    self.sections = sections
    if listItems.isEmpty {
      self.sectionIndexTitles = nil
    } else {
      self.sectionIndexTitles = refinedSectionIndexTitles
    }
  }

  var isEmpty: Bool {
    return numberOfSections == 0
  }

  var numberOfSections: Int {
    return sections.count
  }

  var numberOfMovies: Int {
    var count = 0
    for section in sections {
      if let dataSource = section.dataSource {
        count += dataSource.numberOfMovies
      }
    }
    return count
  }

  func item(at indexPath: IndexPath) -> MovieListController.ListItem {
    guard let dataSource = sections[indexPath.section].dataSource else {
      preconditionFailure("there is no data source at the given section")
    }
    return dataSource.item(at: indexPath.row)
  }

  func indexPath(for item: MovieListController.ListItem) -> IndexPath? {
    let sectionIndexTitle = grouping.sectionIndexTitle(for: item.movie)
    if let sectionIndex = sectionIndexBySectionIndexTitle[sectionIndexTitle],
       let rowIndex = sections[sectionIndex].dataSource?.index(for: item) {
      return IndexPath(row: rowIndex, section: sectionIndex)
    }
    return nil
  }

  func numberOfMovies(in sectionIndex: Int) -> Int {
    return sections[sectionIndex].dataSource?.numberOfMovies ?? 0
  }

  func titleForHeader(in sectionIndex: Int) -> String? {
    return sections[sectionIndex].title
  }

  func sectionForSectionIndexTitle(_ title: String, at sectionIndex: Int) -> Int {
    return sections[sectionIndex].dataSource == nil ? -1 : sectionIndex
  }

  func filtered(by filter: (MovieListController.ListItem) -> Bool) -> [MovieListController.ListItem] {
    var result = [MovieListController.ListItem]()
    for section in sections {
      if let dataSource = section.dataSource {
        result.append(contentsOf: dataSource.filtered(by: filter))
      }
    }
    return result
  }
}
