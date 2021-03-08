# SelfSizingScroller
Fixes scrollToRow/ItemAtIndexPath: for Self Sizing Cells

Self sizing cells in UITableView and UICollectionView are great, but
they make `scrollToRowAtIndexPath:` and `scrollToItemAtIndexPath:`
stop working reliably.

This small library adds a `reallyScrollTo...` variants to UITableView and UICollectionView that reliably scroll to the right position by doing the scrolling itself using CADisplayLink, and adjusting when needed.

## for UITableView:
```
UITableView.reallyScrollToRow(at indexPath: IndexPath, at scrollPosition: UITableView.ScrollPosition, animated: Bool)

```

## for UICollectionView:
```
func reallyScrollToItem(at indexPath: IndexPath, at scrollPosition: UICollectionView.ScrollPosition, animated: Bool)
```

## Extendable
 The actual scrolling and determing where to scroll to are separated, so it's easy to extend by implementing a single method in a protocol:
 ```
 protocol ScrollOffsetProviderProtocol {
 func targetScrollOffset(witStartOffset startOffset: CGPoint) -> CGPoint?
 }
 ```
 
 and then call:
 ```
class MyScrollOffsetProvider: ScrollOffsetProviderProtocol {
  func targetScrollOffset(witStartOffset startOffset: CGPoint) -> CGPoint? {
    // calculate actual position, gets called on every animation frame.
	// It's fine to return different positions on each invocation,
	// as long as it eventually stabilizes.
    return ...;
  }
}
 let scrollView = UIScrollView()
 scrollView.scrollTo
 ```
 
Just dynamically return which offset to scroll to and the library will make it happen.
