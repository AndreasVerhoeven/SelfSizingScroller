//
//  CollectionViewScrollOffsetProvider.swift
//  ScrollerTest
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit

extension UICollectionView {
	// An offset provider that scrolls to an IndexPath
	// in a collectionview at the given position.
	public struct ScrollOffsetProvider: ScrollOffsetProviderProtocol {
		public weak var collectionView: UICollectionView?
		public var indexPath: IndexPath
		public var position: UICollectionView.ScrollPosition
		public var positionInsets: UIEdgeInsets = .zero

		public func targetScrollOffset(withStartOffset startOffset: CGPoint) -> CGPoint? {
			guard let collectionView = collectionView else { return nil }
			guard indexPath.section < collectionView.numberOfSections else { return nil }
			guard indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) else { return nil }
			guard let itemFrame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { return nil }

			// TODO: Compositional Layout scrolling is not taking orthogonal scrolling into account, figure out how

			return UIScrollView.ScrollOffsetProvider.targetScrollOffset(withStartOffset: startOffset,
																		for: itemFrame,
																		horizontalPosition: position.scrollOffsetProviderHorizontalPosition,
																		verticalPosition: position.scrollOffsetProviderVerticalPosition,
																		positionInsets: positionInsets,
																		in: collectionView)
		}
	}
}

extension UIScrollView.Scroller {
	// helper function to make a Scroller scroll to an index path in a collectionview
	public func scrollToItem(at indexPath: IndexPath,
					  in collectionView: UICollectionView,
					  position: UICollectionView.ScrollPosition,
					  positionInsets: UIEdgeInsets = .zero,
					  animated: Bool,
					  completion: Callback<UICollectionView>.CompletionHandler? = nil) {
		let provider = UICollectionView.ScrollOffsetProvider(collectionView: collectionView, indexPath: indexPath, position: position, positionInsets: positionInsets)
		startScrolling(with: provider, in: collectionView, animated: animated, completion: Callback<UICollectionView>.wrapped(completion))
	}
}

// maps from UICollectionView.ScrollPosition to our scroll positions
fileprivate extension UICollectionView.ScrollPosition {
	var scrollOffsetProviderHorizontalPosition: UIScrollView.ScrollOffsetProvider.Position {
		if contains(.left) {
			return .start
		} else if contains(.centeredHorizontally) {
			return .center
		} else if contains(.right) {
			return .end
		} else {
			return .visible
		}
	}

	var scrollOffsetProviderVerticalPosition: UIScrollView.ScrollOffsetProvider.Position {
		if contains(.top) {
			return .start
		} else if contains(.centeredVertically) {
			return .center
		} else if contains(.bottom) {
			return .end
		} else {
			return .visible
		}
	}
}
