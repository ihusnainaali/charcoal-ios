//
//  Copyright © FINN.no AS, Inc. All rights reserved.
//

import Charcoal
import FinniversKit
import UIKit

// MARK: - DemoViewsTableViewController

class DemoViewsTableViewController: UITableViewController {

    // MARK: - Override properties

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - Setup

    init() {
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let indexPath = Sections.lastSelectedIndexPath else { return }
        presentViewController(for: indexPath)
    }

    private func setup() {
        tableView.register(UITableViewCell.self)
        tableView.backgroundColor = UIColor.secondaryBlue
        tableView.delegate = self
        tableView.separatorStyle = .none
    }

    private func filterContainer(forMarket market: String, using config: FilterConfiguration) -> FilterContainer {
        let filterSetup = DemoFilter.filterDataFromJSONFile(named: market)
        let demoFilter = DemoFilter(filter: filterSetup)
        let filter = filterSetup.filterContainer(using: config)
        filter.verticals = demoFilter.verticalSetup.subVerticals(for: market)
        return filter
    }

    private func presentViewController(for indexPath: IndexPath) {
        let section = Sections.allCases[indexPath.section]
        switch section {
        case .components:
            guard let viewController = Sections.viewController(for: indexPath) else { return }
            let transitionStyle = Sections.transitionStyle(for: indexPath)
            presentViewControllerWithPossibleDismissGesture(viewController, transitionStyle: transitionStyle)
        case .fullscreen:
            guard let market = Sections.marketName(for: indexPath), let config = FilterMarket(market: market) else { return }

            let filter = filterContainer(forMarket: market, using: config)
            let controller = CharcoalViewController(filter: filter, config: config)
            controller.filterDelegate = self
            controller.mapFilterViewManager = MapViewManager()
            controller.searchLocationDataSource = DemoSearchLocationDataSource()

            let bottomSheet = BottomSheet(rootViewController: controller)
            present(bottomSheet, animated: true)
        }
    }
}

// MARK: - UITableViewDelegate

extension DemoViewsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Sections.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = Sections.allCases[safe: section]
        return section?.numberOfItems ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(UITableViewCell.self, for: indexPath)
        cell.textLabel?.text = Sections.formattedName(for: indexPath)
        cell.textLabel?.font = UIFont.title3
        cell.textLabel?.textColor = UIColor.milk
        cell.selectionStyle = .none
        cell.backgroundColor = .clear

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        Sections.lastSelectedIndexPath = indexPath
        presentViewController(for: indexPath)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Sections.formattedName(for: section)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        Sections.lastSelectedIndexPath = nil
        super.dismiss(animated: flag, completion: completion)
    }
}

// MARK: - CharcoalViewControllerDelegate

extension DemoViewsTableViewController: CharcoalViewControllerDelegate {
    func charcoalViewController(_ filterViewController: CharcoalViewController, didChangeSelection selection: [URLQueryItem]) {
        print("Selection did change")
    }

    func charcoalViewController(_ viewController: CharcoalViewController, didSelect vertical: Vertical) {
        guard let vertical = vertical as? VerticalDemo, let config = FilterMarket(market: vertical.id) else { return }

        let filter = filterContainer(forMarket: vertical.id, using: config)

        viewController.isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            viewController.filter = filter
            viewController.config = config
        }
    }
}

extension DemoViewsTableViewController {
    func presentViewControllerWithPossibleDismissGesture(_ viewController: UIViewController, transitionStyle: TransitionStyle) {
        switch transitionStyle {
        case .bottomSheet:
            let bottomSheet = BottomSheet(rootViewController: viewController)
            present(bottomSheet, animated: true)
            return
        default:
            break
        }

        present(viewController, animated: true) {
            if transitionStyle != .bottomSheet {
                let dismissGesture = UITapGestureRecognizer(target: self, action: #selector(self.closeCurrentlyPresentedViewController))
                dismissGesture.numberOfTapsRequired = 2
                dismissGesture.numberOfTouchesRequired = 2
                viewController.view.addGestureRecognizer(dismissGesture)
            }
        }
    }

    @objc func closeCurrentlyPresentedViewController() {
        dismiss(animated: true)
    }
}
