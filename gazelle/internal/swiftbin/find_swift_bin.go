package swiftbin

import (
	"os/exec"
	"runtime"
)

func SwiftBinBase() string {
	switch runtime.GOOS {
	case "windows":
		return "swift.exe"
	default:
		return "swift"
	}
}

func FindSwiftBinPath() (string, error) {
	swiftBinBase := SwiftBinBase()
	return exec.LookPath(swiftBinBase)
}
