import UIKit

class SortDescriptorViewController: UITableViewController {

  private var sectionHeader: String!
  private var sectionText: [String]!
  private var selectedIndex: Int!
  private var callback: ((Int) -> Void)!

  func configure(options: (String, [String], Int?), callback: @escaping (Int) -> Void) {
    self.sectionHeader = options.0
    self.sectionText = options.1
    self.selectedIndex = options.2
    self.callback = callback
    tableView.reloadData()
  }

  @IBAction func saveOptions(segue: UIStoryboardSegue) {
    callback!(selectedIndex)
    self.dismiss(animated: true)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
      case 0: return sectionText.count
      default: fatalError("TableView should only have one section ")
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard indexPath.section == 0 else { fatalError("TableView should only have one section ") }

    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    cell.textLabel!.text = sectionText[indexPath.row]
    if selectedIndex == indexPath.row {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
    return cell
  }

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return sectionHeader
      default: fatalError("TableView should only have one section ")
    }
  }

  public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard indexPath.section == 0 else { fatalError("TableView should only have one section ") }

    tableView.deselectRow(at: indexPath, animated: true)
    if let previousSelection = selectedIndex {
      tableView.cellForRow(at: IndexPath(row: previousSelection, section: indexPath.section))!.accessoryType = .none
    }
    selectedIndex = indexPath.row

    tableView.cellForRow(at: indexPath)!.accessoryType = .checkmark
  }
}
