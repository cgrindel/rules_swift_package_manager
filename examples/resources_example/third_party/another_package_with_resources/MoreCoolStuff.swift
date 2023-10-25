import SwiftUI

public enum MoreCoolStuff {
    public static func title() -> Text {
        return Text("Another Title", bundle: .module)
    }

    public static func image() -> Image {
        return Image("avatar", bundle: .module)
    }
}
