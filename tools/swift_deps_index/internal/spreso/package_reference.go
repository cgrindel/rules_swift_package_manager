package spreso

import "encoding/json"

// A PkgRefKind is an enum representing the kind of package reference.
type PkgRefKind int

const (
	UnknownPkgRefKind PkgRefKind = iota
	RootPkgRefKind
	FileSystemPkgRefKind
	LocalSourceControlPkgRefKind
	RemoteSourceControlPkgRefKind
	RegistryPkgRefKind
)

func (prk *PkgRefKind) UnmarshalJSON(b []byte) error {
	var jsonVal string
	if err := json.Unmarshal(b, &jsonVal); err != nil {
		return err
	}
	switch jsonVal {
	case "root":
		*prk = RootPkgRefKind
	case "fileSystem":
		*prk = FileSystemPkgRefKind
	case "localSourceControl":
		*prk = LocalSourceControlPkgRefKind
	case "remoteSourceControl":
		*prk = RemoteSourceControlPkgRefKind
	case "registry":
		*prk = RegistryPkgRefKind
	}
	return nil
}

// A PackageReference represents a serialized form of PackageModel.PackageReference
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackageModel/PackageReference.swift
type PackageReference struct {
	Identity string
	Kind     PkgRefKind
	Location string
	Name     string
}

// Remote returns the location of the remote package.
func (pr *PackageReference) Remote() string {
	// We probably want to use a different value based upon the Kind
	return pr.Location
}
