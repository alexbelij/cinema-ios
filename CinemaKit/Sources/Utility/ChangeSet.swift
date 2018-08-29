public struct ChangeSet<ItemID: Hashable, Item> {
  public internal(set) var insertions: [Item]
  public internal(set) var modifications: [ItemID: Item]
  public internal(set) var deletions: [ItemID: Item]
  var hasInternalChanges = false
  var hasPublicChanges: Bool {
    return !insertions.isEmpty || !modifications.isEmpty || !deletions.isEmpty
  }

  init(insertions: [Item] = [], modifications: [ItemID: Item] = [:], deletions: [ItemID: Item] = [:]) {
    self.insertions = insertions
    self.modifications = modifications
    self.deletions = deletions
  }
}
