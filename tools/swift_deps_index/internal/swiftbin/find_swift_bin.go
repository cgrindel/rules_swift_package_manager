package swiftbin

import (
	"os/exec"
	"runtime"
)

// SwiftBinBase returns the base name for the Swift executable.
func SwiftBinBase() string {
	switch runtime.GOOS {
	case "windows":
		return "swift.exe"
	default:
		return "swift"
	}
}

// FindSwiftBinPath returns the path to the Swift executable.
func FindSwiftBinPath() (string, error) {
	swiftBinBase := SwiftBinBase()
	return exec.LookPath(swiftBinBase)
}
