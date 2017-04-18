//
// Created by Martin Bauer on 17.04.17.
// Copyright (c) 2017 Martin Bauer. All rights reserved.
//

import Foundation

class Utils {
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
