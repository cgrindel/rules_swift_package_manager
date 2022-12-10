package spreq

import "gopkg.in/yaml.v3"

type Requirements struct {
	Dependencies []*Dependency
}

func NewRequirementsFromYAML(b []byte) (*Requirements, error) {
	var reqs Requirements
	if err := yaml.Unmarshal(b, &reqs); err != nil {
		return nil, err
	}
	return &reqs, nil
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
