//
//  ViewController.swift
//  ScrollerTest
//
//  Created by Andreas Verhoeven on 08/03/2021.
//

import UIKit

class ViewController: UITableViewController {
	var itemHeights = Array<CGFloat>()

	func reload() {
		itemHeights = (0..<3000).map { _ in CGFloat(Int.random(in: 40..<150)) }
		tableView.reloadData()
	}

	func scroll(usesUIKit: Bool) {
		let row = Int.random(in: 0..<itemHeights.count)

		if usesUIKit == true {
			tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: true)
		} else {
			tableView.reallyScrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: true)
		}
		title = "scrolled to: \(row)"
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.estimatedRowHeight = 10
		tableView.rowHeight = UITableView.automaticDimension

		let scrollBarButtonItem = UIBarButtonItem(title: "Scroll", style: .plain, target: nil, action: nil)
		scrollBarButtonItem.menu = UIMenu(title: "", children: [
			UIAction(title: "UIKit Scrolling", handler: { [weak self] _ in
				self?.scroll(usesUIKit: true)
			}),

			UIAction(title: "Improved Scrolling", handler: { [weak self] _ in
				self?.scroll(usesUIKit: false)
			})
		])
		let reloadBarButtonItem = UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction(handler: { [weak self] _ in
			self?.reload()
		}))

		navigationItem.rightBarButtonItems = [
				reloadBarButtonItem,
				scrollBarButtonItem,
		]

		reload()
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return itemHeights.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
		let height = itemHeights[indexPath.row]
		cell.textLabel?.text = "row \(indexPath.row), height = \(height)"
		for constraint in cell.contentView.constraints {
			if constraint.firstAttribute == .height {
				cell.removeConstraint(constraint)
			}
		}
		cell.contentView.heightAnchor.constraint(equalToConstant: height).isActive = true
		return cell
	}

}

