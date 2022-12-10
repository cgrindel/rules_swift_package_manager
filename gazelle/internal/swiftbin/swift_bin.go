package swiftbin

import (
	"bytes"
	"fmt"
	"os/exec"
)

type Executor interface {
	InitPackage(dir, name, pkgType string) error
	DumpPackage(dir string) ([]byte, error)
	DescribePackage(dir string) ([]byte, error)
}

type SwiftBin struct {
	BinPath string
}

func NewSwiftBin(binPath string) *SwiftBin {
	return &SwiftBin{BinPath: binPath}
}

func (sb *SwiftBin) InitPackage(dir, name, pkgType string) error {
	args := []string{"package", "init", "--name", name, "--type", pkgType}
	cmd := exec.Command(sb.BinPath, args...)
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed executing `swift package init`, out\n%v: %w", string(out), err)
	}
	return nil
}

func (sb *SwiftBin) DumpPackage(dir string) ([]byte, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd := exec.Command(sb.BinPath, "package", "dump-package")
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

func (sb *SwiftBin) DescribePackage(dir string) ([]byte, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd := exec.Command(sb.BinPath, "package", "describe", "--type", "json")
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

func (sb *SwiftBin) ResolvePackage(dir string) error {
	args := []string{"package", "resolve"}
	cmd := exec.Command(sb.BinPath, args...)
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed executing `swift package resolve`, out\n%v: %w", string(out), err)
	}
	return nil
}
