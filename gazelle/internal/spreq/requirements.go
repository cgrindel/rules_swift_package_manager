package spreq

type Requirements struct {
	Dependencies []*Dependency
}

type Dependency struct {
	Remote *RemoteDependency
	Local  *LocalDependency
}

type RemoteDependency struct {
	Name     string
	URL      string
	Version  string
	Revision string
	Branch   string
}

type LocalDependency struct {
	Name string
	Path string
}
