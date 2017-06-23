import UIKit

class StringOptionsTableViewController: UITableViewController {

  private var sectionHeaders: [String]!
  private var sectionText: [[String]]!
  private var selectedIndices: [Int: Int]!
  private var callback: (([Int: Int]) -> Void)!

  func configure(options: [(String,[String],Int?)], callback: @escaping ([Int: Int]) -> Void) {
    self.sectionHeaders = options.map({ $0.0 })
    self.sectionText = options.map({ $0.1 })
    self.selectedIndices = [:]
    options.enumerated().forEach({ self.selectedIndices[$0.offset] = $0.element.2 })
    self.callback = callback
    tableView.reloadData()
  }

  @IBAction func saveOptions(segue: UIStoryboardSegue) {
    callback!(selectedIndices)
    self.dismiss(animated: true)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return sectionText.count
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sectionText[section].count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    cell.textLabel!.text = sectionText[indexPath.section][indexPath.row]
    if selectedIndices[indexPath.section] == indexPath.row {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
    return cell
  }

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sectionHeaders[section]
  }

  public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if let previousSelection = selectedIndices[indexPath.section] {
      tableView.cellForRow(at: IndexPath(row: previousSelection, section: indexPath.section))!.accessoryType = .none
    }
    selectedIndices[indexPath.section] = indexPath.row

    tableView.cellForRow(at: indexPath)!.accessoryType = .checkmark
  }
}
