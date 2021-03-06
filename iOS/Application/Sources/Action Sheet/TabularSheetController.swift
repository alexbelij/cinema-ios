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
    var previousStyle: SheetItemGroupingStyle?
    for item in sheetItems {
      if item.groupingStyle != previousStyle || previousStyle == .detached {
        previousStyle = item.groupingStyle
        groups.append([SheetItem]())
      }
      groups[groups.endIndex - 1].append(item)
    }
    return groups
  }

  private let scrollView = UIScrollView()
  private var cancelTableView: UITableView?
  private var tableControllers = [ArrayTableController<SheetItem>]()
  private var registeredCells = [String: UINib]()
  private let cellConfig: AnyTabularSheetCellConfiguration<SheetItem>

  private let sheetMargin: CGFloat = 10.0
  private let groupGap: CGFloat = 10.0
  private let sheetCornerRadius: CGFloat = 14.0

  private var contentWidth: CGFloat = 0.0
  private var scrollableContentHeight: CGFloat = 0.0
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
    scrollView.bounces = false
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.layer.cornerRadius = sheetCornerRadius
    scrollView.scrollIndicatorInsets = UIEdgeInsets(top: sheetCornerRadius,
                                                    left: 0,
                                                    bottom: sheetCornerRadius,
                                                    right: 0)
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
    let safeAreaInsets = view.safeAreaInsets
    let topMargin = max(safeAreaInsets.top, sheetMargin)
    let bottomMargin = max(safeAreaInsets.bottom, sheetMargin)
    let bounds = presentingViewController!.view.bounds
    let maxHeight = bounds.height - topMargin - bottomMargin
    let cancelGroupHeight = cancelTableView == nil ? 0 : cancelTableView!.contentSize.height + groupGap
    let scrollViewHeight = scrollableContentHeight + cancelGroupHeight <= maxHeight
        ? scrollableContentHeight
        : maxHeight - cancelGroupHeight
    scrollView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: scrollViewHeight)
    if cancelTableView != nil {
      cancelTableView!.frame.origin = CGPoint(x: 0, y: scrollViewHeight + groupGap)
    }
    let contentHeight = cancelGroupHeight + scrollViewHeight
    view.frame = CGRect(x: (bounds.width - self.contentWidth) / 2,
                        y: bounds.origin.y + bounds.height - contentHeight - bottomMargin,
                        width: contentWidth,
                        height: contentHeight)
  }

  private func setUpContentView() {
    guard !self.sheetItems.isEmpty else { preconditionFailure("there must be at least one sheet item") }
    contentWidth = min(self.view.bounds.width, self.view.bounds.height) - 2 * sheetMargin
    view.addSubview(scrollView)
    scrollableContentHeight = 0.0

    // all groups except last one (cancel)
    sheetItemGroups.forEach { group in
      let arrayTableController = ArrayTableController(sheetItemType: .array(group),
                                                      cellConfig: cellConfig,
                                                      presentingViewController: self)
      let tableView = setUpTableView(tableController: arrayTableController) { tableView in
        registeredCells.forEach { identifier, nib in tableView.register(nib, forCellReuseIdentifier: identifier) }
      }
      scrollView.addSubview(tableView)
      tableView.layoutIfNeeded()
      let tableViewHeight = tableView.contentSize.height
      tableView.frame = CGRect(x: 0,
                               y: scrollableContentHeight,
                               width: contentWidth,
                               height: tableViewHeight)
      scrollableContentHeight += tableViewHeight + groupGap
    }
    scrollableContentHeight -= groupGap
    scrollView.contentSize = CGSize(width: contentWidth, height: scrollableContentHeight)

    // last group (cancel)
    if cellConfig.showsCancelAction {
      let arrayTableController = ArrayTableController(sheetItemType: .cancel,
                                                      cellConfig: cellConfig,
                                                      presentingViewController: self)
      cancelTableView = setUpTableView(tableController: arrayTableController) { tableView in
        tableView.register(CancelCell.self, forCellReuseIdentifier: "CancelCell")
      }
      view.addSubview(cancelTableView!)
      cancelTableView!.layoutIfNeeded()
      let tableViewHeight = cancelTableView!.contentSize.height
      // origin is set in viewWillLayoutSubviews
      cancelTableView!.frame = CGRect(x: 0, y: 0, width: contentWidth, height: tableViewHeight)
    }
  }

  private func setUpTableView(tableController: ArrayTableController<SheetItem>,
                              cellRegistering: (UITableView) -> Void) -> UITableView {
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
    return tableView
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

  func cell(for sheetItem: SheetItem, at indexPath: IndexPath, cellDequeuing: TableViewDequeuing) -> UITableViewCell

  var showsCancelAction: Bool { get }

  var localizedCancelString: String { get }

  func cancelCell(for indexPath: IndexPath, cellDequeuing: TableViewDequeuing) -> UITableViewCell
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

  public func cancelCell(for indexPath: IndexPath, cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    let cell: CancelCell = cellDequeuing.dequeueReusableCell(for: indexPath)
    cell.label.textColor = cell.tintColor
    cell.label.text = localizedCancelString
    return cell
  }
}

class CancelCell: UITableViewCell {
  fileprivate let label: UILabel

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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

  func cell(for sheetItem: SheetItem,
            at indexPath: IndexPath,
            cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    _abstract()
  }

  var showsCancelAction: Bool {
    _abstract()
  }

  var localizedCancelString: String {
    _abstract()
  }

  func cancelCell(for indexPath: IndexPath, cellDequeuing: TableViewDequeuing) -> UITableViewCell {
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

  override func cell(for sheetItem: Base.SheetItem,
                     at indexPath: IndexPath,
                     cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    return base.cell(for: sheetItem, at: indexPath, cellDequeuing: cellDequeuing)
  }

  override var showsCancelAction: Bool {
    return base.showsCancelAction
  }

  override var localizedCancelString: String {
    return base.localizedCancelString
  }

  override func cancelCell(for indexPath: IndexPath, cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    return base.cancelCell(for: indexPath, cellDequeuing: cellDequeuing)
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

  public func cell(for sheetItem: SheetItem,
                   at indexPath: IndexPath,
                   cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    return box.cell(for: sheetItem, at: indexPath, cellDequeuing: cellDequeuing)
  }

  public var showsCancelAction: Bool {
    return box.showsCancelAction
  }

  public var localizedCancelString: String {
    return box.localizedCancelString
  }

  public func cancelCell(for indexPath: IndexPath, cellDequeuing: TableViewDequeuing) -> UITableViewCell {
    return box.cancelCell(for: indexPath, cellDequeuing: cellDequeuing)
  }
}
