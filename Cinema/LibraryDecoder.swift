//
// Created by Martin Bauer on 18.06.17.
// Copyright (c) 2017 Martin Bauer. All rights reserved.
//

import Foundation

protocol LibraryDecoder {

  func decode(fromString string: String) throws -> [MediaItem]

}

enum LibraryDecoderError: Error {
  case invalidFormat
}
