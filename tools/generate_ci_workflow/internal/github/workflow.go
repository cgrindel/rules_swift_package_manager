package github

import (
	"github.com/creasty/defaults"
	"gopkg.in/yaml.v3"
)

type Workflow struct {
	Name string           `yaml:"name"`
	On   WorkflowTriggers `yaml:"on"`
	Jobs map[string]Job   `yaml:"jobs" default:"{}"`
}

func NewWorkflowFromYAML(b []byte) (*Workflow, error) {
	var workflow Workflow
	if err := defaults.Set(&workflow); err != nil {
		return nil, err
	}
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
	Needs    []string          `yaml:"needs,omitempty"`
	If       string            `yaml:"if,omitempty"`
	Env      map[string]string `yaml:"env,omitempty"`
	Steps    []Step            `yaml:"steps"`
}

func (j *Job) UnmarshalYAML(node *yaml.Node) error {
	// Need to set defaults on Job, because they are stored in a map. The Strategy defaults will not
	// be set unless we do it from here.
	if err := defaults.Set(j); err != nil {
		return nil
	}
	// Define a type so that we can unmarshal into the struct without a recursion error.
	type fake Job
	if err := node.Decode((*fake)(j)); err != nil {
		return err
	}
	return nil
}

type Step struct {
	Uses  string            `yaml:"uses,omitempty"`
	If    string            `yaml:"if,omitempty"`
	With  map[string]string `yaml:"with,omitempty"`
	Name  string            `yaml:"name,omitempty"`
	Shell string            `yaml:"shell,omitempty"`
	Run   string            `yaml:"run,omitempty"`
}

type Strategy struct {
	FailFast FailFast         `yaml:"fail-fast,omitempty" default:"true"`
	Matrix   SBMatrixStrategy `yaml:"matrix,omitempty"`
}

func (s *Strategy) UnmarshalYAML(node *yaml.Node) error {
	// Set defaults on Strategy
	if err := defaults.Set(s); err != nil {
		return nil
	}
	// Define a type so that we can unmarshal into the struct without a recursion error.
	type fake Strategy
	if err := node.Decode((*fake)(s)); err != nil {
		return err
	}
	return nil
}

type FailFast bool

func (ff FailFast) IsZero() bool {
	// The FailFast defaults to true
	return bool(ff)
}

type SBMatrixStrategy struct {
	Example      []string          `yaml:"example,omitempty"`
	BazelVersion []string          `yaml:"bazel_version,omitempty"`
	Include      []SBMatrixInclude `yaml:"include,omitempty"`
}

type SBMatrixInclude struct {
	Example      string `yaml:"example"`
	BazelVersion string `yaml:"bazel_version"`
	Runner       string `yaml:"runner"`
	EnableBzlmod bool   `yaml:"enable_bzlmod"`
}
