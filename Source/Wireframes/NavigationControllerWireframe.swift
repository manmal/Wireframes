import UIKit


open class NavigationControllerWireframe: ViewControllerWireframe, NavigationControllerWireframeInterface {

	override public var currentlyActiveChildWireframe: WireframeInterface? {
		return childWireframes.last
	}

	override public var viewController: UIViewController {
		return navigationController
	}

	fileprivate let navigationController: UINavigationController

	fileprivate var _childWireframes: [ViewControllerWireframeInterface] = []
	fileprivate var childWireframes: [ViewControllerWireframeInterface] {
		get {
			return _childWireframes
		}
		set(newValue) {
			setChildWireframes(newValue, animated: false)
		}
	}

	func setChildWireframes(_ childWireframes: [ViewControllerWireframeInterface], animated: Bool) {
		let oldChildWireframes = _childWireframes
		guard !oldChildWireframes.elementsEqual(childWireframes, by: { $0 === $1 }) else {
			return
		}

		assert(childWireframes.count > 0)
		// IMPORTANT: the childWireframes array needs to be set BEFORE setting the navigationController.setViewControllers
		_childWireframes = childWireframes
		childWireframes.forEach { wireframe in
			wireframe.parentWireframe = self
		}
		let newViewControllers = childWireframes.map({ wireframe in wireframe.viewController })
		navigationController.setViewControllers(newViewControllers, animated: animated)
	}

	/** IMPORTANT
		from this point on this Wireframe manages the UINavigationController instance
		* do not set its `delegate` property, as this Wireframe needs the delegate calls to track the correct state
		* do not modify its `viewControllers` property, rather use NavigationCommands for that
		* do not use any presenting or push/pop methods from it, rather use NavigationCommands for that
	 */
	public init(navigationController: UINavigationController, childWireframes: [ViewControllerWireframeInterface]) {
		self.navigationController = navigationController
		super.init(viewController: navigationController)

		self.navigationController.delegate = self
		self.childWireframes = childWireframes
	}

	override public func handle(_ navigationCommand: NavigationCommand) -> Bool {
		if super.handle(navigationCommand) {
			return true
		}

		if let navigationCommand = navigationCommand as? NavigationControllerNavigationCommand {
			switch navigationCommand {
				case .push(let wireframe, let animated):
					assert(!(wireframe is NavigationControllerWireframeInterface))
					pushWireframe(wireframe, animated: animated)
				case .pop(let wireframe, let animated):
					assert(!(wireframe is NavigationControllerWireframeInterface))
					popWireframe(wireframe, animated: animated)
				case .replaceStack(let wireframes, let animated):
					assert(!wireframes.contains(where: { $0 is NavigationControllerWireframeInterface }))
					setChildWireframes(wireframes, animated: animated)
			}
			return true
		}

		return false
	}

	private func pushWireframe(_ wireframe: ViewControllerWireframeInterface, animated: Bool) {
		var newWireframes = childWireframes
		newWireframes.append(wireframe)
		setChildWireframes(newWireframes, animated: animated)
	}

	private func popWireframe(_ wireframe: ViewControllerWireframeInterface, animated: Bool) {
		guard let last = childWireframes.last, wireframe === last else {
			assertionFailure()
			return
		}

		var newWireframes = childWireframes
		_ = newWireframes.popLast()
		setChildWireframes(newWireframes, animated: animated)
	}

}

extension NavigationControllerWireframe: UINavigationControllerDelegate {

	public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
		// navigationController.viewControllers already represents the stack AFTER showing the viewController
		// notice that this delegate method is called even when an interactive movement (back swipe) is started, and later aborted - should rather be called `mightShow viewController`
	}

	public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		// NOTE: when the system back button/swipe or is used, or an already active tab item is clicked, we need to correctly update childWireframes

		// we know that such a user action has happened when the navigationController.viewControllers array does not match the childWireframes array
		let childWireframesOutOfSync = navigationController.viewControllers != Array(childWireframes.map({ $0.viewController }))

		// the target viewController might have been shown already (when navigating back), but might also not: when starting the app with the first tab segment active, and then switching tab and pushing in one command chain, will/didShow is called for each viewcontroller on the stack separately, and the viewControllers array does not include the last pushed viewcontroller for the first call
		let wireframeToBeShownWasShownBeforeAlready = childWireframes.first(where: { $0.viewController === viewController })?.wasShown ?? false

		if childWireframesOutOfSync, wireframeToBeShownWasShownBeforeAlready {
			let lastNavigationState = currentNavigationState()
			// IMPORTANT: use _childWireframes setter, and NOT childWireframes setter, as we do not want setViewControllers to be called as a side effect
			_childWireframes = navigationController.viewControllers.flatMap({ viewController in
				if let existingWireframe = childWireframes.first(where: { $0.viewController === viewController }) {
					return existingWireframe
				} else {
					fatalError("childWireframes did not contain ViewController \(viewController) - childWireframes needs to be a superset of the viewControllers array - method pushWireframe(_:) needs to be used, or set childWireframes directly")
				}
			})
			dispatch(UIKitNavigationCommand.uikitDidChangeNavigationState(previousNavigationState: lastNavigationState))
		}

		assert(childWireframes.count >= navigationController.viewControllers.count, "always use NavigationCommands instead of directly pushing/popping")

		// mark ALL childWireframes with wasShown, as when showing several wireframes at once, the ones in between have already been correctly added to the childWireframes array
		childWireframes.forEach({ $0.wasShown = true })
	}

}
