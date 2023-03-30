import UIKit

func moduleLocalized(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

func moduleImage(_ name: String) -> UIImage? {
    UIImage(named: name, in: .module, with: nil)
}
