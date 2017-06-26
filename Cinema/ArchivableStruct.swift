protocol ArchivableStruct {

  var dataDictionary: [String: Any] { get }

  init(dataDictionary dict: [String: Any])

}
