import Dispatch
import UIKit

// MARK: - Sheet Items

public protocol SheetItemProtocol {
  var groupingStyle: SheetItemGroupingStyle { get }
  var handler: ((Self) -> Void)? { get }
}

public enum SheetItemGroupingStyle {
  case detached
  case grouped
}

// MARK: - TabularSheetController

public class TabularSheetController<SheetItem: SheetItemProtocol>: UIViewController,
    UIViewControllerTransitioningDelegate {

  private var sheetItems = [SheetItem]()
  private var sheetItemGroups: [[SheetItem]] {
    var groups = [[SheetItem]]()
    var previousStyle: SheetItemGroupingStyle? = nil
    for item in sheetItems {
      if item.groupingStyle != previousStyle || previousStyle == .detached {
        previousStyle = item.groupingStyle
        groups.append([SheetItem]())
      }
      groups[groups.endIndex - 1].append(item)
    }
    return groups
  }

  private var tableControllers = [ArrayTableController<SheetItem>]()
  private var registeredCells = [String: UINib]()
  private let cellConfig: AnyTabularSheetCellConfiguration<SheetItem>

  public var sheetMargin: CGFloat = 10.0
  public var sheetCornerRadius: CGFloat = 14.0

  private var contentWidth: CGFloat = 0.0
  private var contentHeight: CGFloat = 0.0
  private var hasViewBeenShown = false

  public init<C: TabularSheetCellConfiguration>(cellConfig: C) where C.SheetItem == SheetItem {
    self.cellConfig = AnyTabularSheetCellConfiguration(cellConfig)
    super.init(nibName: nil, bundle: nil)
    self.modalPresentationStyle = .custom
    self.transitioningDelegate = self
    cellConfig.nibCellTypes.forEach { cellType in
      let identifier = String(describing: cellType)
      registeredCells[identifier] = UINib(nibName: identifier, bundle: cellConfig.nibCellBundle)
    }
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("TabularSheetController must be initialized via init(cellConfig:)")
  }

  // MARK: - Sheet Configuration

  public func addSheetItem(_ item: SheetItem) {
    sheetItems.append(item)
  }

  // MARK: - Table View Setup

  override public func viewWillAppear(_ animated: Bool) {
    guard !hasViewBeenShown else { preconditionFailure("TabularSheetController can only be shown once") }
    super.viewWillAppear(animated)
    setUpContentView()
  }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.hasViewBeenShown = true
  }

  override public func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    let bounds = presentingViewController!.view.bounds
    view.frame = CGRect(x: (bounds.width - self.contentWidth) / 2,
                        y: bounds.origin.y + bounds.height - self.contentHeight
                           - presentingViewController!.view.safeAreaInsets.bottom,
                        width: contentWidth,
                        height: contentHeight)
  }

  private func setUpContentView() {
    guard !self.sheetItems.isEmpty else { preconditionFailure("there must be at least one sheet item") }
    contentWidth = min(self.view.bounds.width, self.view.bounds.height) - 2 * sheetMargin
    contentHeight = 0.0
    sheetItemGroups.forEach { group in
      self.setUpTableView(tableController: ArrayTableController(sheetItemType: .array(group),
                                                                cellConfig: self.cellConfig,
                                                                presentingViewController: self)) { tableView in
        registeredCells.forEach { identifier, nib in tableView.register(nib, forCellReuseIdentifier: identifier) }
      }
    }
    if cellConfig.showsCancelAction {
      self.setUpTableView(tableController: ArrayTableController(sheetItemType: .cancel,
                                                                cellConfig: self.cellConfig,
                                                                presentingViewController: self)) { tableView in
        tableView.register(CancelCell.self, forCellReuseIdentifier: "CancelCell")
      }
    }
    let bounds = presentingViewController!.view.bounds
    view.frame = CGRect(x: (bounds.width - self.contentWidth) / 2,
                        y: bounds.origin.y + bounds.height,
                        width: contentWidth,
                        height: contentHeight)
  }

  private func setUpTableView(tableController: ArrayTableController<SheetItem>,
                              cellRegistering: (UITableView) -> Void) {
    self.tableControllers.append(tableController)
    let tableView = UITableView(frame: .zero, style: .plain)
    tableView.backgroundColor = .clear
    tableView.bounces = false
    tableView.dataSource = tableController
    tableView.delegate = tableController
    tableView.isScrollEnabled = false
    tableView.showsVerticalScrollIndicator = false
    tableView.separatorInset = .zero
    tableView.layer.cornerRadius = self.sheetCornerRadius
    tableView.layer.masksToBounds = true
    cellRegistering(tableView)
    view.addSubview(tableView)

    tableView.layoutIfNeeded()
    tableView.frame = CGRect(x: 0,
                             y: contentHeight,
                             width: contentWidth,
                             height: tableView.contentSize.height)
    contentHeight += tableView.frame.height + sheetMargin
  }

  // MARK: - UIViewControllerTransitioningDelegate

  public func presentationController(forPresented presented: UIViewController,
                                     presenting: UIViewController?,
                                     source: UIViewController) -> UIPresentationController? {
    return DimmingPresentationController(presentedViewController: presented, presenting: presenting)
  }
}

// MARK: - Cell Configuration

public protocol TabularSheetCellConfiguration: class {
  associatedtype SheetItem

  var nibCellTypes: [UITableViewCell.Type] { get }

  var nibCellBundle: Bundle? { get }

  var cellHeight: CGFloat { get }

  func cell(for sheetItem: SheetItem, cellDequeuing: CellDequeuing) -> UITableViewCell

  var showsCancelAction: Bool { get }

  var localizedCancelString: String { get }

  func cancelCell(cellDequeuing: CellDequeuing) -> UITableViewCell
}

public extension TabularSheetCellConfiguration {
  public var nibCellBundle: Bundle? {
    return nil
  }

  public var cellHeight: CGFloat {
    return 57.0
  }

  public var showsCancelAction: Bool {
    return true
  }

  public func cancelCell(cellDequeuing: CellDequeuing) -> UITableViewCell {
    let cell = cellDequeuing.dequeueReusableCell(CancelCell.self)
    cell.label.textColor = cell.tintColor
    cell.label.text = localizedCancelString
    return cell
  }
}

class CancelCell: UITableViewCell {
  fileprivate let label: UILabel

  override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
    label = UILabel()
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    self.contentView.addSubview(label)
    label.textAlignment = .center
    label.font = UIFont.boldSystemFont(ofSize: 20)
    label.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|[label]|",
                                                               options: [],
                                                               metrics: nil,
                                                               views: ["label": label]))
    NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|[label]|",
                                                               options: [],
                                                               metrics: nil,
                                                               views: ["label": label]))
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("CancelCell must be initialized via int(style:reuseIdentifier:)")
  }
}

// MARK: - Type Erasure For TabularSheetCellConfiguration

private class _AnyTabularSheetCellConfigurationBoxBase<SheetItem>: TabularSheetCellConfiguration {
  private func _abstract() -> Never {
    fatalError("must be overridden")
  }

  var nibCellTypes: [UITableViewCell.Type] {
    _abstract()
  }

  var nibCellBundle: Bundle? {
    _abstract()
  }

  var cellHeight: CGFloat {
    _abstract()
  }

  func cell(for sheetItem: SheetItem, cellDequeuing: CellDequeuing) -> UITableViewCell {
    _abstract()
  }

  var showsCancelAction: Bool {
    _abstract()
  }

  var localizedCancelString: String {
    _abstract()
  }

  func cancelCell(cellDequeuing: CellDequeuing) -> UITableViewCell {
    _abstract()
  }
}

private class _TabularSheetCellConfigurationBox<Base: TabularSheetCellConfiguration>:
    _AnyTabularSheetCellConfigurationBoxBase<Base.SheetItem> {
  private let base: Base

  init(_ base: Base) {
    self.base = base
  }

  override var nibCellTypes: [UITableViewCell.Type] {
    return base.nibCellTypes
  }

  override var nibCellBundle: Bundle? {
    return base.nibCellBundle
  }
  override var cellHeight: CGFloat {
    return base.cellHeight
  }

  override func cell(for sheetItem: Base.SheetItem, cellDequeuing: CellDequeuing) -> UITableViewCell {
    return base.cell(for: sheetItem, cellDequeuing: cellDequeuing)
  }

  override var showsCancelAction: Bool {
    return base.showsCancelAction
  }

  override var localizedCancelString: String {
    return base.localizedCancelString
  }

  override func cancelCell(cellDequeuing: CellDequeuing) -> UITableViewCell {
    return base.cancelCell(cellDequeuing: cellDequeuing)
  }
}

public class AnyTabularSheetCellConfiguration<SheetItem>: TabularSheetCellConfiguration {
  private let box: _AnyTabularSheetCellConfigurationBoxBase<SheetItem>

  public init<X: TabularSheetCellConfiguration>(_ base: X) where X.SheetItem == SheetItem {
    self.box = _TabularSheetCellConfigurationBox(base)
  }

  public var nibCellTypes: [UITableViewCell.Type] {
    return box.nibCellTypes
  }

  public var nibCellBundle: Bundle? {
    return box.nibCellBundle
  }

  public var cellHeight: CGFloat {
    return box.cellHeight
  }

  public func cell(for sheetItem: SheetItem, cellDequeuing: CellDequeuing) -> UITableViewCell {
    return box.cell(for: sheetItem, cellDequeuing: cellDequeuing)
  }

  public var showsCancelAction: Bool {
    return box.showsCancelAction
  }

  public var localizedCancelString: String {
    return box.localizedCancelString
  }

  public func cancelCell(cellDequeuing: CellDequeuing) -> UITableViewCell {
    return box.cancelCell(cellDequeuing: cellDequeuing)
  }
}
