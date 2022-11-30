package spreso

type PkgRefKind int

const (
	UnknownPkgRefKind PkgRefKind = iota
	RootPkgRefKind
	FileSystemPkgRefKind
	LocalSourceControlPkgRefKind
	RemoteSourceControlPkgRefKind
	RegistryPkgRefKind
)

// Represents serialized form of PackageModel.PackageReference
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackageModel/PackageReference.swift
type PackageReference struct {
	Identity string
	Kind     PkgRefKind
	Location string
	Name     string
}
