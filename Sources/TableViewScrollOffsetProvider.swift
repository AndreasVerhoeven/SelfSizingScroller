//
//  TableViewScrollOffsetProvider.swift
//  ScrollerTest
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit

extension UITableView {

	// A scroll provider that scrolls to an IndexPath
	// in the tableview to a certain ScrollPosition.
	public struct ScrollOffsetProvider: ScrollOffsetProviderProtocol {
		public weak var tableView: UITableView?
		public var indexPath: IndexPath
		public var position: UITableView.ScrollPosition

		public func targetScrollOffset(witStartOffset startOffset: CGPoint) -> CGPoint? {
			guard let tableView = tableView else { return nil }
			guard indexPath.section < tableView.numberOfSections else { return nil }
			guard indexPath.row < tableView.numberOfRows(inSection: indexPath.section) else { return nil }
			let rowRect = tableView.rectForRow(at: indexPath)

			return UIScrollView.ScrollOffsetProvider.targetScrollOffset(withStartOffset: startOffset,
																		for: rowRect,
																		horizontalPosition: .none,
																		verticalPosition: position.scrollOffsetProviderPosition,
																		in: tableView)
		}
	}
}

extension UIScrollView.Scroller {
	// helper function to make a Scroller scroll to an index path in a tableview
	public func scrollToRow(at indexPath: IndexPath,
					 in tableView: UITableView,
					 position: UITableView.ScrollPosition,
					 animated: Bool) {
		let provider = UITableView.ScrollOffsetProvider(tableView: tableView, indexPath: indexPath, position: position)
		startScrolling(with: provider, in: tableView, animated: animated)
	}
}

// helper to convert from UITableView.ScrollPosition to our scroll position enum
fileprivate extension UITableView.ScrollPosition {
	var scrollOffsetProviderPosition: UIScrollView.ScrollOffsetProvider.Position {
		switch self {
			case .none: return .visible
			case .top: return .start
			case .middle: return .center
			case .bottom: return .end

			@unknown default:
				return .visible
		}
	}
}
