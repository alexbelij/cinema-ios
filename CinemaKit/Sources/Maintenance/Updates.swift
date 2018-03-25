public enum UpdateUtils {
  public static func updates(from version: SchemaVersion, using movieDb: MovieDbClient) -> [PropertyUpdate] {
    switch version {
      case .v1_0_0: return [GenreIdsUpdate(movieDb: movieDb), ReleaseDateUpdate(movieDb: movieDb)]
      case .v2_0_0: return []
    }
  }
}
