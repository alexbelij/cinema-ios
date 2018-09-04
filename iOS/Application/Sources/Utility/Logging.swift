import os.log

enum Logging {
  static func createLogger(category: String) -> OSLog {
    return OSLog(subsystem: "de.martinbauer.cinema", category: category)
  }
}
