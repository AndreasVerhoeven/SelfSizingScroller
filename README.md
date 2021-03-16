# SelfSizingScroller
Fixes `scrollToRow/ItemAtIndexPath:` for Self Sizing Cells

Self sizing cells in UITableView and UICollectionView are great, but
they make `scrollToRowAtIndexPath:` and `scrollToItemAtIndexPath:`
stop working reliably.

This small library adds a `reallyScrollTo...` variants to UITableView and UICollectionView that reliably scroll to the right position by doing the scrolling itself using CADisplayLink, and adjusting when needed.

## for UITableView:
```
public func reallyScrollToRow(at indexPath: IndexPath,
                              at scrollPosition: UITableView.ScrollPosition,
                              insets: UIEdgeInsets = .zero,
                              animated: Bool,
                              completion: ((UITableView, _ hasCompleted: Bool) -> Void)? = nil)

```


## for UICollectionView:
```
func reallyScrollToItem(at indexPath: IndexPath,
                        at scrollPosition: UICollectionView.ScrollPosition, 
                        insets: UIEdgeInsets = .zero,
						animated: Bool,
						completion: ((UICollectionView, _ hasCompleted: Bool) -> Void)? = nil)
```

## Extras

### Additional Insets
You can specify additional insets that will be respected when scrolling. For example, if you want to scroll a row 10 points below the top, you can use `at: .top, insets: UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)` 

### CompletionHandler
There's an optional completionHandler that will be called when scrolling is done with a `hasCompleted` flag to indicate if we fully scrolled to the designated offset or if we were interrupted.

### isScrolling flag
Additionally, checking `scrollView.scroller.isScrolling` also works to see if we're currently in a scroll animation.

## Extendable
 The actual scrolling and determining where to scroll to are separated, so it's easy to extend by implementing a single method in a protocol:
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
	// as long as it eventually stabilizes (otherwise we'll scroll
	// forever).
    return ...;
  }
}
 
let scrollView = UIScrollView()
let provider = MyScrollOffsetProvider()
scrollView.startScrolling(with: provider, animated: true)
 ```
 
Just dynamically return which offset to scroll to and the library will make it happen.
