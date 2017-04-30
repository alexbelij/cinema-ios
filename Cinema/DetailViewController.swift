//
//  DetailViewController.swift
//  Cinema
//
//  Created by Martin Bauer on 17.04.17.
//  Copyright © 2017 Martin Bauer. All rights reserved.
//

import Dispatch
import UIKit

class DetailViewController: UIViewController {

  var detailItem: MediaItem? {
    didSet {
      configureView()
    }
  }

  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var subtitleLabel: UILabel!
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var runtimeLabel: UILabel!
  @IBOutlet weak var yearLabel: UILabel!

  var movieDb: MovieDbClient!

  func configureView() {
    guard isViewLoaded else { return }
    if let mediaItem = detailItem {
      titleLabel.text = mediaItem.title
      if let subtitle = mediaItem.subtitle {
        subtitleLabel.isHidden = false
        subtitleLabel.text = subtitle
      } else {
        subtitleLabel.isHidden = true
      }
      runtimeLabel.text = Utils.formatDuration(mediaItem.runtime)
      yearLabel.text = "\(mediaItem.year)"

      if movieDb.isConnected {
        fetchAdditionalData()
      }
    }
  }

  private func fetchAdditionalData() {
    DispatchQueue.global(qos: .userInitiated).async {
      if let poster = self.movieDb.poster(for: self.detailItem!.id, size: .w185) {
        DispatchQueue.main.async {
          self.imageView.image = poster
        }
      }
    }
  }

  private func localizedDiskType(_ diskType: DiskType) -> String {
    switch diskType {
      case .dvd: return "DVD"
      case .bluRay: return "Blu-ray"
    }
  }

  override func viewDidLoad() {
    runtimeLabel?.text = ""
    yearLabel?.text = ""
    configureView()
    super.viewDidLoad()
  }
}

