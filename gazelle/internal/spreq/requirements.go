package spreq

type Requirements struct {
	Dependencies []*Dependency
}

type Dependency struct {
	Remote *RemoteDependency
	Local  *LocalDependency
}

type RemoteDependency struct {
	URL         string
	Requirement *DependencyRequirement
}

type DependencyRequirement struct {
	Exact    string
	Revision string
	Branch   string
}

type LocalDependency struct {
	Path string
}
