import Foundation

class Utils {

  static func applicationSupportDirectory() -> URL {
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    if urls.count >= 1 {
      let appSupportUrl = urls[0]
      let appDirectory = appSupportUrl.appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
      do {
        try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
      } catch {}
    }
    fatalError("Could not create Application Support directory")
  }

  static func formatDuration(_ duration: Int) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [ .hour, .minute ]
    formatter.zeroFormattingBehavior = [ .dropAll ]

    return formatter.string(from: Double(duration * 60))!
  }

  static func fullTitle(of mediaItem: MediaItem) -> String {
    if let subtitle = mediaItem.subtitle {
      return "\(mediaItem.title): \(subtitle)"
    } else {
      return mediaItem.title
    }
  }
}
