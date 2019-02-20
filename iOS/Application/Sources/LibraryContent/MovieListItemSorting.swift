import Foundation

protocol MovieListItemSorting {
  func areInIncreasingOrder(left: MovieListController.ListItem, right: MovieListController.ListItem) -> Bool
}

struct TitleSorting: MovieListItemSorting {
  func areInIncreasingOrder(left: MovieListController.ListItem, right: MovieListController.ListItem) -> Bool {
    let title1 = left.movie.title.removingIgnoredPrefixes()
    let title2 = right.movie.title.removingIgnoredPrefixes()
    switch title1.compare(title2, options: [.diacriticInsensitive, .caseInsensitive]) {
      case .orderedSame:
        guard let leftDate = left.movie.releaseDate else { return false }
        guard let rightDate = right.movie.releaseDate else { return true }
        return leftDate <= rightDate
      case .orderedAscending: return true
      case .orderedDescending: return false
    }
  }
}

struct RuntimeSorting: MovieListItemSorting {
  func areInIncreasingOrder(left: MovieListController.ListItem, right: MovieListController.ListItem) -> Bool {
    guard let leftRuntime = left.movie.runtime else { return false }
    guard let rightRuntime = right.movie.runtime else { return true }
    return leftRuntime <= rightRuntime
  }
}
