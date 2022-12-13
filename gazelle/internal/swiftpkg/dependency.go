package swiftpkg

type Dependency struct {
	Identity    string
	Type        string
	URL         string
	Requirement DependencyRequirement
}

// Requirement

type DependencyRequirement struct {
	Range []VersionRange
}

type VersionRange struct {
	LowerBound string
	UpperBound string
}
