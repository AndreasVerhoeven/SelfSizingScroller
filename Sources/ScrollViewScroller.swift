//
//  ScrollViewScroller.swift
//  Scroller
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit

// we add the suffix `Protocol` here, since we also want to
// have classes named `.ScrollOffsetProvider` extending this protocol, but
// swift gets confused what we mean if we do that.
public protocol ScrollOffsetProviderProtocol {

	// should return the offset we should scroll to, or nil if we shouldn't scroll.
	// - this implementation should be fast, since it will be queried every animation frame
	// - values can change every frame, of course (that's the whole point of this exercise)
	func targetScrollOffset(withStartOffset startOffset: CGPoint) -> CGPoint?
}

extension UIScrollView {
	// self sizing cells + scrollToRow/ItemAtIndexPath isn't worked great in UIKit.
	// This class works around that by doing our own scrolling:
	//	 - we check where we should be
	//	 - we add that as a target to scroll by
	//   - we start animating towards that by calculating a new position every frame
	//     using CADisplayLink
	//   - every frame, we check if where we should be has changed, if so
	//     we add another target for the change.
	//   - every frame, we calculate for each target how much we should add (or substract)
	//     towards our new position
	//   - we do this, until we reach the end
	//
	// We "animate" multiple targets independently, so that if we get a big jump, we ease
	// in the speed difference.
	//
	// For example:
	//  - at start we figure out we should move from 100 -> 900, thus we'll scroll 800 points in 0.25s
	//     rougly 50 points per frame
	//  - after 0.1s, we see that we should actually scroll to 1200, so we need to make up 500 points
	//    in 0.15s, which is 32 points per frame,
	//  - so after 0.15 we roughly will scroll by 82 points.
	//
	// The values here are not exact, due to use using an ease-in-out curve
	//
	// Providing our target scroll offset has been abstracted in the
	// `ScrollOffsetProviderProtocol` protocol, so there can be different implementations
	// for UITableView and UICollectionView, while sharing the logic of the actual scrolling here.
	public class Scroller {

		// the duration of the animation, changeable
		public var animationDuration = TimeInterval(0.25)

		public private(set) var isScrolling = false

		// scrollview and provider we're scrolling in, the scrollview
		// is retained weakly.
		public private(set) weak var scrollView: UIScrollView?
		public private(set) var offsetProvider: ScrollOffsetProviderProtocol?

		// completion
		public typealias CompletionHandler = Callback<UIScrollView>.CompletionHandler
		private var completionHandler: CompletionHandler?

		// to drive our animation
		private var elapsedAnimationTime = TimeInterval(0)
		private var displayLink: CADisplayLink?

		// how it's started - where we are going
		private var startOffset = CGPoint.zero
		private var currentTargetPoint = CGPoint.zero

		// our targets, split out by axis
		private var horizontalTargets = Array<Target>()
		private var verticalTargets = Array<Target>()

		deinit {
			stopScrolling(hasCompleted: false, shouldCallCompletionHandler: false)
		}

		// actually starts scrolling in a scrollview towards the offset given
		// by an offset provider.
		// If animated == false, we won't animate but set the correct offset directly

		public func startScrolling(with offsetProvider: ScrollOffsetProviderProtocol,
								   in scrollView: UIScrollView,
								   animated: Bool = true,
								   completion completionHandler: CompletionHandler? = nil) {

			stopScrolling()

			self.scrollView = scrollView
			self.offsetProvider = offsetProvider
			self.completionHandler = completionHandler
			elapsedAnimationTime = 0
			startOffset = scrollView.contentOffset
			currentTargetPoint = startOffset
			horizontalTargets.removeAll()
			verticalTargets.removeAll()

			if animated {
				isScrolling = true

				// pre-emptively check if we need to scroll
				addTargetsIfNeeded(start: 0)
				guard verticalTargets.count > 0 || horizontalTargets.count > 0 else {
					return stopScrolling(hasCompleted: true)
				}

				// animated, we're gonna start a display link to drive our animation
				if displayLink == nil {
					let newDisplayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
					if #available(iOS 15, *) {
						// https://developer.apple.com/documentation/quartzcore/optimizing_promotion_refresh_rates_for_iphone_13_pro_and_ipad_pro
						newDisplayLink.preferredFrameRateRange = CAFrameRateRange(minimum:80, maximum:120, preferred:120)
					}
					displayLink = newDisplayLink
					newDisplayLink.add(to: .main, forMode: .common)
				}

			} else {
				isScrolling = true

				// not animated, so we just go to the position that is indicated to us, force layout and then check again
				// until we've stabilized
				while true {
					guard let offset = offsetProvider.targetScrollOffset(withStartOffset: startOffset) else { break }
					if offset.isAlmostEqual(to: scrollView.contentOffset) { break }
					scrollView.setContentOffset(offset, animated: false)
					scrollView.setNeedsLayout()
					scrollView.layoutIfNeeded()
				}
				stopScrolling(hasCompleted: true)
			}
		}

		// stops scrolling
		public func stopScrolling() {
			stopScrolling(hasCompleted: false)
		}

		private func stopScrolling(hasCompleted: Bool, shouldCallCompletionHandler: Bool = true) {
			guard isScrolling else { return }

			horizontalTargets.removeAll()
			verticalTargets.removeAll()

			isScrolling = false
			displayLink?.invalidate()
			displayLink = nil

			let handler = completionHandler
			completionHandler = nil
			if shouldCallCompletionHandler == true , let handler = handler, let scrollView = scrollView {
				handler(scrollView, hasCompleted)
			}
		}

		private var actualAnimationDuration: TimeInterval {
			#if targetEnvironment(simulator)
				return animationDuration * TimeInterval(UIAnimationDragCoefficient())
			#else
				return animationDuration
			#endif
		}

		private func addTargetsIfNeeded(start: TimeInterval = 0) {
			guard let target = offsetProvider?.targetScrollOffset(withStartOffset: startOffset) else { return }

			let timeToStillAnimate = actualAnimationDuration - elapsedAnimationTime
			let duration = max(0.125, timeToStillAnimate)

			// check what our current target is (where we are scrolling to) and if it has changed,
			// if so, we'll add a new Target for the difference, so that adding each target
			// will in the end land us at the correct scroll position.

			// Note that we separate the targets by axis.
			let difference = CGPoint(x: target.x - currentTargetPoint.x, y: target.y - currentTargetPoint.y)

			if  difference.x != 0 {
				horizontalTargets.append(Target(value: difference.x, start: start, duration: duration))
			}

			if difference.y != 0 {
				verticalTargets.append(Target(value: difference.y, start: start, duration: duration))
			}
			currentTargetPoint = target
		}

		private func calculateNewOffset(for time: TimeInterval) -> CGPoint {
			// the point where we should be at the given time
			let x = horizontalTargets.reduce(0) { $0 + $1.easedValue(for: time) }
			let y = verticalTargets.reduce(0) { $0 + $1.easedValue(for: time) }
			return CGPoint(x: x, y: y)
		}

		@objc private func displayLinkFired(_ displayLink: CADisplayLink) {
			// check if we should still be scrolling (a finger down on the scrollview stops scrolling)
			guard let scrollView = scrollView else { return stopScrolling(hasCompleted: false, shouldCallCompletionHandler: false) }
			guard scrollView.panGestureRecognizer.state == .possible  else { return stopScrolling(hasCompleted: false) }

			// check how much we have progressed
			let elapsedFrameTime = (displayLink.targetTimestamp - displayLink.timestamp)
			elapsedAnimationTime += elapsedFrameTime

			// our target contentOffset might have changed, add new targets if that happened
			addTargetsIfNeeded(start: elapsedAnimationTime)

			if currentTargetPoint.isAlmostEqual(to: scrollView.contentOffset)
				|| (horizontalTargets.isEmpty && verticalTargets.isEmpty) {
				// if we're at out position or there are no targets to animate, we're done and can stop scrolling
				return stopScrolling(hasCompleted: true)
			}

			// calculate our new offset and set it, and wait until the next frame
			let value = calculateNewOffset(for: elapsedAnimationTime)
			let newOffset = CGPoint(x: startOffset.x + value.x, y: startOffset.y + value.y)
			scrollView.setContentOffset(newOffset, animated: false)
		}
	}
}

fileprivate extension UIScrollView.Scroller {
	// for each change in target, we create a target
	// that we animate independently
	private struct Target {
		var value: CGFloat // the amount we should add to the offset

		var start: TimeInterval // when we started in the current scroll cycle (at the beginning = 0)
		var duration: TimeInterval // the duration we have to animate

		func isDone(for elapsedTime: TimeInterval) -> Bool {
			return elapsedTime >= duration + start
		}

		func elapsedTimeInTarget(for elapsedTime: TimeInterval) -> TimeInterval {
			return max(0, min(elapsedTime - start, duration))
		}

		func linearProgress(for totalElapsedTime: TimeInterval) -> CGFloat {
			let elapsedTime = elapsedTimeInTarget(for: totalElapsedTime)
			let progress = max(0, min(elapsedTime / duration, 1))
			return CGFloat(progress)
		}

		func easedProgress(for totalElapsedTime: TimeInterval) -> CGFloat {
			// we used a cheap ease-in-out curve using a modified cos() curve
			let progress = linearProgress(for: totalElapsedTime)
			return (cos(progress * .pi - .pi) + 1) / 2
		}

		func easedValue(for totalElapsedTime: TimeInterval) -> CGFloat {
			let progress = easedProgress(for: totalElapsedTime)
			return progress * value
		}
	}
}

public extension UIScrollView.Scroller {
	enum Callback<ViewType: UIScrollView> {
		public typealias CompletionHandler = (ViewType, _ hasCompleted: Bool) -> Void

		static func wrapped(_ handler: CompletionHandler?) -> Callback<UIScrollView>.CompletionHandler? {
			guard let handler = handler else { return nil }
			return { scrollView, hasCompleted in
				guard let view = scrollView as? ViewType else { return }
				handler(view, hasCompleted)
			}
		}
	}
}


// helpers to compare CGPoint
fileprivate extension CGPoint {
	func isAlmostEqual(to other: CGPoint) -> Bool {
		return isAlmostEqual(to: other, delta: (1.0 / UIScreen.main.scale) * 0.1)
	}

	func isAlmostEqual(to other: CGPoint, delta: CGFloat) -> Bool {
		return x.isAlmostEqual(to: other.x, delta: delta) && y.isAlmostEqual(to: other.y, delta: delta)
	}

}

fileprivate extension CGFloat {
	func isAlmostEqual(to other: CGFloat, delta: CGFloat) -> Bool {
		return abs(self - other) < delta
	}
}

#if targetEnvironment(simulator)
	@_silgen_name("UIAnimationDragCoefficient") func UIAnimationDragCoefficient() -> Float
#endif
