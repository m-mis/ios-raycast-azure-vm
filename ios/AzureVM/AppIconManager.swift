import UIKit

enum AppIconManager {
    static func updateIcon(for powerState: PowerState) {
        let iconName: String?
        switch powerState {
        case .running:
            iconName = "AppIcon-Green"
        case .deallocated, .stopped:
            iconName = "AppIcon-Red"
        default:
            iconName = nil // default icon (gray)
        }

        guard UIApplication.shared.supportsAlternateIcons else { return }

        let currentIcon = UIApplication.shared.alternateIconName
        guard currentIcon != iconName else { return }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error {
                print("Failed to set icon: \(error.localizedDescription)")
            }
        }
    }
}
