public struct ChangeSet<ItemID: Hashable, Item> {
  public let insertions: [Item]
  public let modifications: [ItemID: Item]
  public let deletions: [ItemID: Item]

  init(insertions: [Item] = [], modifications: [ItemID: Item] = [:], deletions: [ItemID: Item] = [:]) {
    self.insertions = insertions
    self.modifications = modifications
    self.deletions = deletions
  }
}
