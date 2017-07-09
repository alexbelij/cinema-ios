enum SortDescriptor {
  case title, runtime, year

  var tableViewStrategy: TableViewSortingStrategy {
    switch self {
      case .title: return TitleSortingStrategy()
      case .runtime: return RuntimeSortingStrategy()
      case .year: return YearSortingStrategy()
    }
  }
}
