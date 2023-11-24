package swiftbin

import (
	"bytes"
	"fmt"
	"os/exec"
)

// An Executor represents commands provided by the Swift binary.
type Executor interface {
	InitPackage(dir, name, pkgType string) error
	DumpPackage(dir, buildDir string) ([]byte, error)
	DescribePackage(dir string) ([]byte, error)
}

// A SwiftBin implements that actual calls to the Swift binary.
type SwiftBin struct {
	BinPath string
}

func NewSwiftBin(binPath string) *SwiftBin {
	return &SwiftBin{BinPath: binPath}
}

// InitPackage initializes a new Swift package in the specified directory.
func (sb *SwiftBin) InitPackage(dir, name, pkgType string) error {
	args := []string{"package", "init", "--name", name, "--type", pkgType}
	cmd := exec.Command(sb.BinPath, args...)
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed executing `swift package init`, out\n%v: %w", string(out), err)
	}
	return nil
}

// DumpPackage returns the `swift package dump-package` JSON for a Swift package.
func (sb *SwiftBin) DumpPackage(dir, buildDir string) ([]byte, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	args := []string{"package", "dump-package"}
	args = appendBuildPath(args, buildDir)
	cmd := exec.Command(sb.BinPath, args...)
	cmd.Dir = dir
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf(
			"failed executing `swift package dump-package`, stderr\n%s: %w",
			stderr.String(),
			err,
		)
	}
	return stdout.Bytes(), nil
}

// DescribePackage returns the `swift package describe` JSON for a Swift package.
func (sb *SwiftBin) DescribePackage(dir string) ([]byte, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	args := []string{"package", "describe", "--type", "json"}
	cmd := exec.Command(sb.BinPath, args...)
	cmd.Dir = dir
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf(
			"failed executing `swift package describe`, stderr\n%s: %w",
			stderr.String(),
			err,
		)
	}
	return stdout.Bytes(), nil
}

// ResolvePackage executes Swift package dependency resolution for a Swift package.
func (sb *SwiftBin) ResolvePackage(dir, buildDir string, updateToLatest bool) error {
	var pkgCmd string
	if updateToLatest {
		pkgCmd = "update"
	} else {
		pkgCmd = "resolve"
	}
	args := []string{"package", pkgCmd}
	args = appendBuildPath(args, buildDir)
	cmd := exec.Command(sb.BinPath, args...)
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed executing `swift package resolve`, out\n%v: %w", string(out), err)
	}
	return nil
}

func appendBuildPath(args []string, buildDir string) []string {
	if buildDir == "" {
		return args
	}
	return append(args, "--build-path", buildDir)
}
