import Wireframes


struct PushSwitchPushCommandChain: NavigationCommandChain {

	func navigationCommandSequence() -> NavigationCommandSequence {
		let titles = Array("ABCDEFGHIJKLM".characters)
		let wfs: [ViewControllerWireframe] = Array(titles.map({ WireframeFactory.createMyVCWireframe(title: String($0), configuration: { _ in }) }))
		assert(titles.count >= 10)
		let pushes1: [NavigationCommand] = wfs[0..<5].map({ NavigationControllerNavigationCommand.push(wireframe: $0, animated: true) })
		let pushes2: [NavigationCommand] = wfs[wfs.count-6..<wfs.count-1].map({ NavigationControllerNavigationCommand.push(wireframe: $0, animated: true) })
		let switchTabCommand = TabBarControllerNavigationCommand.switchTab(toWireframeWithTag: RootTabWireframeTag.second)

		let navigationCommands: [NavigationCommand] = pushes1 + [switchTabCommand] + pushes2
		return NavigationCommandSequence(navigationCommands)
	}

}
