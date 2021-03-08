//
//  ScrollViewScroller+Convenience.swift
//  ScrollerTest
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit
import ObjectiveC.runtime

// Convenience helper: Adds a retained scrolled to a UIScrollView, on demand.
extension UIScrollView {
	private static var scrollerAssociatedObjectKey = 0

	public var scroller: Scroller {
		if let storedScrolled = objc_getAssociatedObject(self, &Self.scrollerAssociatedObjectKey) as? Scroller {
			return storedScrolled
		}
		let scroller = Scroller()
		objc_setAssociatedObject(self, &Self.scrollerAssociatedObjectKey, scroller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		return scroller
	}

	public func startScrolling(with offsetProvider: ScrollOffsetProviderProtocol, animated: Bool = true) {
		scroller.startScrolling(with: offsetProvider, in: self, animated: animated)
	}
}


extension UITableView {
	// helper function to scroll to an indexpath - uses the retained scroller
	public func reallyScrollToRow(at indexPath: IndexPath, at scrollPosition: UITableView.ScrollPosition, animated: Bool) {
		scroller.scrollToRow(at: indexPath, in: self, position: scrollPosition, animated: animated)
	}
}

extension UICollectionView {
	// helper function to scroll to an indexpath - uses the retained scroller
	public func reallyScrollToItem(at indexPath: IndexPath, at scrollPosition: UICollectionView.ScrollPosition, animated: Bool) {
		scroller.scrollToItem(at: indexPath, in: self, position: scrollPosition, animated: animated)
	}
}
