package github

import "gopkg.in/yaml.v3"

type Workflow struct {
	Name string           `yaml:"name"`
	On   WorkflowTriggers `yaml:"on"`
	Jobs map[string]Job   `yaml:"jobs"`
}

func NewWorkflowFromYAML(b []byte) (*Workflow, error) {
	var workflow Workflow
	if err := yaml.Unmarshal(b, &workflow); err != nil {
		return nil, err
	}
	return &workflow, nil
}

type WorkflowTriggers struct {
	PullRequest PullRequestEvent `yaml:"pull_request"`
	Schedule    []Schedule       `yaml:"schedule,omitempty"`
}

type PullRequestEvent struct {
	Branches []string `yaml:"branches,omitempty"`
}

type Schedule struct {
	Cron string `yaml:"cron"`
}

type Job struct {
	Strategy Strategy          `yaml:"strategy,omitempty"`
	RunsOn   string            `yaml:"runs-on"`
	Env      map[string]string `yaml:"env,omitempty"`
	Steps    []Step            `yaml:"steps"`
}

type Step struct {
	Uses  string            `yaml:"uses"`
	With  map[string]string `yaml:"with"`
	Name  string            `yaml:"name"`
	Shell string            `yaml:"shell"`
	Run   string            `yaml:"run"`
}

type Strategy struct {
	Matrix SBMatrixStrategy `yaml:"matrix,omitempty"`
}

type SBMatrixStrategy struct {
	Example      []string          `yaml:"example"`
	BazelVersion []string          `yaml:"bazel_version"`
	Include      []SBMatrixInclude `yaml:"include,omitempty"`
}

type SBMatrixInclude struct {
	Example      string `yaml:"exampletype"`
	BazelVersion string `yaml:"bazel_version"`
}
