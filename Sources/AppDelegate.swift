import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let mainVC = MainViewController()
        let nav = UINavigationController(rootViewController: mainVC)
        nav.isNavigationBarHidden = true
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }

    // Kunci orientasi tetap Full Portrait
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
