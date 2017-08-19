import UIKit

class ListOptionsViewController: UITableViewController {

  private let sortDescriptors: [SortDescriptor] = [.title, .runtime, .year]
  var selectedDescriptor: SortDescriptor? {
    didSet {
      if let descriptor = selectedDescriptor {
        selectedDescriptorIndex = sortDescriptors.index(of: descriptor)
      }
      self.tableView?.reloadData()
    }
  }
  private var selectedDescriptorIndex: Int!
  weak var delegate: ListOptionsViewControllerDelegate?

  override func viewDidLoad() {
    guard selectedDescriptor != nil else { fatalError("selectedDescriptor was not set") }
    super.viewDidLoad()
    title = NSLocalizedString("options", comment: "")
  }

  @IBAction private func saveOptions(segue: UIStoryboardSegue) {
    self.dismiss(animated: true)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
      case 0: return sortDescriptors.count
      default: fatalError("TableView should only have one section ")
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard indexPath.section == 0 else { fatalError("TableView should only have one section ") }

    let cell = tableView.dequeueReusableCell(withIdentifier: "SortDescriptorCell", for: indexPath)
    cell.textLabel!.text = localizedTitle(for: sortDescriptors[indexPath.row])
    if selectedDescriptorIndex == indexPath.row {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
    return cell
  }

  private func localizedTitle(for descriptor: SortDescriptor) -> String {
    switch descriptor {
      case .title: return NSLocalizedString("sort.by.title", comment: "")
      case .runtime: return NSLocalizedString("sort.by.runtime", comment: "")
      case .year: return NSLocalizedString("sort.by.year", comment: "")
    }
  }

  public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
      case 0: return NSLocalizedString("sort.by", comment: "")
      default: fatalError("TableView should only have one section ")
    }
  }

  public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard indexPath.section == 0 else { fatalError("TableView should only have one section ") }

    tableView.deselectRow(at: indexPath, animated: true)

    guard selectedDescriptorIndex != indexPath.row else { return }

    tableView.cellForRow(at: IndexPath(row: selectedDescriptorIndex, section: 0))!.accessoryType = .none
    tableView.cellForRow(at: indexPath)!.accessoryType = .checkmark
    selectedDescriptor = sortDescriptors[indexPath.row]

    delegate?.sortDescriptorDidChange(to: selectedDescriptor!)
  }
}

protocol ListOptionsViewControllerDelegate: class {
  func sortDescriptorDidChange(to descriptor: SortDescriptor)
}