import SwiftyJSON

class JSONDecoder: LibraryDecoder {

  func decode(fromString string: String) throws -> [MediaItem] {
    var data = [MediaItem]()
    if let dataFromString = string.data(using: .utf8, allowLossyConversion: false) {
      let jsonData = JSON(data: dataFromString).arrayValue
      for jsonItem in jsonData {
        let id = jsonItem["id"].int
        let title = jsonItem["title"].string
        let subtitle = jsonItem["subtitle"].string
        let runtime = jsonItem["runtime"].int
        let year = jsonItem["year"].int
        let diskType = DiskType(rawValue: jsonItem["diskType"].string ?? "")
        if let id = id, let title = title, let runtime = runtime, let year = year, let diskType = diskType {
          let mediaItem = MediaItem(id: id,
                                    title: title,
                                    subtitle: subtitle,
                                    runtime: runtime,
                                    year: year,
                                    diskType: diskType)
          data.append(mediaItem)
        } else {
          throw LibraryDecoderError.invalidFormat
        }
      }
    }
    return data
  }
}
