public import SwiftUI

public enum CoolStuff {
    public static func title() -> Text {
        return Text("Title", bundle: .module)
    }

    public static func image() -> Image {
        return Image("avatar", bundle: .module)
    }
}
