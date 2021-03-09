//
//  ScrollViewScrollOffsetProvider.swift
//  ScrollerTest
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit

extension UIScrollView {
	// An offset provider that takes a horizontal and vertical position
	// and a block that provides a rect where we should be scrolled to,
	// taking the horizontal and vertical position into account.
	public class ScrollOffsetProvider: ScrollOffsetProviderProtocol {
		
		public enum Position {
			case none // don't change scroll position
			case start // scroll to the start of the axis
			case center // scroll to the center of the axis
			case end // scroll to the end of the axis
			case visible // scroll into the visible area of the axis
		}

		public private(set) weak var scrollView: UIScrollView?
		public let horizontalPosition: Position // the horizontal "edge" position of the rect where should land
		public let verticalPosition: Position // the vertical "edge" position of the rect where should land

		// this callback can be set to provide a rect of the target we want to show
		public typealias RectProviderCallback = (UIScrollView) -> CGRect?
		public var rectProvider: RectProviderCallback?

		public init(scrollView: UIScrollView,
			 horizontalPosition: Position = .none,
			 verticalPosition: Position = .none,
			 rectProvider: RectProviderCallback? = nil) {

			self.scrollView = scrollView
			self.horizontalPosition = horizontalPosition
			self.verticalPosition = verticalPosition
			self.rectProvider = rectProvider
		}

		// static helper function that calculated the correct target offset
		// given the parameters. Used by UICollectionView.ScrollOffsetProvider
		// and UITableView.ScrollOffsetProvider
		public static func targetScrollOffset(withStartOffset startOffset: CGPoint,
									   for rect: CGRect,
									   horizontalPosition: Position,
									   verticalPosition: Position,
									   in scrollView: UIScrollView) -> CGPoint? {
			let visibleFrame = scrollView.visibleFrame
			let x = horizontalPosition.resolve(value: rect.horizontalLine,
											   visible: visibleFrame.horizontalLine,
											   current: startOffset.x)
			let y = verticalPosition.resolve(value: rect.verticalLine,
											 visible: visibleFrame.verticalLine,
											 current: startOffset.y)

			let currentOffset = scrollView.contentOffset
			let offset = CGPoint(x: x ?? currentOffset.x, y: y ?? currentOffset.y)
			return scrollView.clampOffsetToScrollableBounds(offset)
		}

		public func targetScrollOffset(witStartOffset startOffset: CGPoint) -> CGPoint? {
			guard let scrollView = scrollView else { return nil }
			guard let rect = rectProvider?(scrollView) else { return nil }
			return Self.targetScrollOffset(withStartOffset: startOffset,
										   for: rect,
										   horizontalPosition: horizontalPosition,
										   verticalPosition: verticalPosition,
										   in: scrollView)
		}
	}
}

fileprivate extension CGRect {
	// helper
	var horizontalLine: UIScrollView.ScrollOffsetProvider.Position.Line { .init(start: minX, end: maxX) }
	var verticalLine: UIScrollView.ScrollOffsetProvider.Position.Line { .init(start: minY, end: maxY) }
}

fileprivate extension UIScrollView.ScrollOffsetProvider.Position {
	// a line on an axis with a start and endpoint
	struct Line {
		var start: CGFloat
		var end: CGFloat

		var length: CGFloat {end - start}
		var center: CGFloat { start + length * 0.5}
		func contains(_ value: CGFloat) -> Bool { value >= start && value < end }
		func contains(_ line: Line) -> Bool { contains(line.start) && contains(line.end) }
		func offset(by offset: CGFloat) -> Line { Line(start: start + offset, end: end + offset) }
	}

	// this resolves the scroll position on a single axis in a scrollview, given the parameters:
	// value = the line we want to scroll to
	// visible = the frame that is visible
	// current = the position we're starting from
	func resolve(value: Line, visible: Line, current: CGFloat) -> CGFloat? {
		switch self {
			case .none: return nil
			case .visible:
				let currentLine = visible.offset(by: current)
				if currentLine.contains(value) {
					// fully visible, no need to scroll
					return nil
				} else {
					// not visible, determine if the target is before our current position and, if so, scroll the target to start,
					// otherwise to end: that way we make sure that we stop scrolling once the contents is visible.
					let position: UIScrollView.ScrollOffsetProvider.Position = (value.start < currentLine.start ? .start : .end)
					return position.resolve(value: value, visible: visible, current: current)
				}
			case .start: return value.start - visible.start
			case .center: return visible.center - value.length * 0.5
			case .end: return value.end - visible.end
		}
	}
}

fileprivate extension UIScrollView {
	// the frame that can be considered visible, and not obscured by insets
	var visibleFrame: CGRect {
		let rect = CGRect(origin: .zero, size: bounds.size)
		return rect.inset(by: adjustedContentInset)
	}

	// the bounds in which we can offset, any offset outside this
	// will make our scrollview bounce
	var offsettableBounds: CGRect {
		let insets = adjustedContentInset
		let contentSize = self.contentSize
		let visibleFrame =  self.visibleFrame
		let offsettableRect = CGRect(x: -insets.left,
									 y: -insets.top,
									 width: max(0, contentSize.width - visibleFrame.width),
									 height: max(0, contentSize.height - visibleFrame.height))
		return offsettableRect
	}

	// clamps an offset to the scrollable bounds, so that we don't overscroll
	func clampOffsetToScrollableBounds(_ offset: CGPoint) -> CGPoint {
		let rect = offsettableBounds
		return CGPoint(x: max(rect.minX, min(offset.x, rect.maxX)), y: max(rect.minY, min(offset.y, rect.maxY)))
	}
}
