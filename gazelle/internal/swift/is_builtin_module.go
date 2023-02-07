package swift

import mapset "github.com/deckarep/golang-set/v2"

//

// https://docs.elementscompiler.com/Platforms/Cocoa/Frameworks/iOSSDKFrameworks/
var iosFrameworks = mapset.NewSet[string]()

// https://docs.elementscompiler.com/Platforms/Cocoa/Frameworks/OSXSDKFrameworks/
var macosFrameworks = mapset.NewSet[string]()

var otherBuiltInModules = mapset.NewSet[string]()

var allBuiltInModules = mapset.NewSet[string](
	"AppKit",
	"Foundation",
	"SwiftUI",
	"UIKit",
	"XCTest",
)

// IsBuiltInModule determines if the module is built into the Swift standard library.
func IsBuiltInModule(name string) bool {
	return allBuiltInModules.Contains(name)
}
