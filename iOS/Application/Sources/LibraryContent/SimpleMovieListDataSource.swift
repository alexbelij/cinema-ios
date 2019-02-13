import CinemaKit
import UIKit

class SimpleMovieListDataSource {
  private var listItems: [MovieListController.ListItem]
  private var indexes: [TmdbIdentifier: Int]

  init(listItems: [MovieListController.ListItem], sortingStrategy: SectionSortingStrategy) {
    self.listItems = listItems.sorted { left, right in
      sortingStrategy.movieSorting(left: left.movie, right: right.movie)
    }
    self.indexes = Dictionary(minimumCapacity: listItems.count)
    for (index, listItem) in self.listItems.enumerated() {
      indexes[listItem.tmdbID] = index
    }
  }

  var isEmpty: Bool {
    return numberOfMovies == 0
  }

  var numberOfMovies: Int {
    return listItems.count
  }

  func item(at index: Int) -> MovieListController.ListItem {
    return listItems[index]
  }

  func index(for item: MovieListController.ListItem) -> Int? {
    return indexes[item.tmdbID]
  }

  func filtered(by filter: (MovieListController.ListItem) -> Bool) -> [MovieListController.ListItem] {
    return listItems.filter(filter)
  }
}
