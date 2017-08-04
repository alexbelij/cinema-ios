import Foundation

class Utils {

  static func formatDuration(_ duration: Int) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [ .hour, .minute ]
    formatter.zeroFormattingBehavior = [ .dropAll ]

    return formatter.string(from: Double(duration * 60))!
  }
}
