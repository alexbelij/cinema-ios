protocol LibraryDecoder {

  func decode(fromString string: String) throws -> [MediaItem]

}

enum LibraryDecoderError: Error {
  case invalidFormat
}
