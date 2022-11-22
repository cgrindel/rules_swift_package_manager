package swiftbin

import "io"

type Executor interface {
	ResolvePackage(dir string) error
	DumpPackage(dir string) (io.Reader, error)
	// DescribePackage(dir string) (io.Reader, error)
}

type SwiftBin struct {
	BinPath string
}

func NewSwiftBin(binPath string) *SwiftBin {
	return &SwiftBin{BinPath: binPath}
}

func (sb *SwiftBin) ResolvePackage(dir string) error {
	// TODO(chuck): IMPLEMENT ME!
	return nil
}

func (sb *SwiftBin) DumpPackage(dir string) (io.Reader, error) {
	// TODO(chuck): IMPLEMENT ME!
	return nil, nil
}
