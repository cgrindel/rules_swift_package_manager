package github

import (
	"github.com/creasty/defaults"
	"gopkg.in/yaml.v3"
)

// Workflow is a GitHub Actions workflow
type Workflow struct {
	Name        string           `yaml:"name"`
	On          WorkflowTriggers `yaml:"on"`
	Concurrecny Concurrency      `yaml:"concurrency"`
	Jobs        map[string]Job   `yaml:"jobs" default:"{}"`
}

// NewWorkflowFromYAML returns a new workflow from YAML bytes.
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

// WorkflowTriggers represents the triggers for a workflow.
type WorkflowTriggers struct {
	PullRequest PullRequestEvent `yaml:"pull_request"`
	Schedule    []Schedule       `yaml:"schedule,omitempty"`
}

// PullRequestEvent is a trigger event.
type PullRequestEvent struct {
	Branches []string `yaml:"branches,omitempty"`
}

// Schedule is the cron schedule for a workflow.
type Schedule struct {
	Cron string `yaml:"cron"`
}

// Concurrency describes how concurrent workflows should be handled.
type Concurrency struct {
	Group            string `yaml:"group"`
	CancelInProgress bool   `yaml:"cancel-in-progress"`
}

// Job describes a GitHub actions workflow job.
type Job struct {
	Strategy Strategy          `yaml:"strategy,omitempty"`
	RunsOn   string            `yaml:"runs-on"`
	Needs    []string          `yaml:"needs,omitempty"`
	If       string            `yaml:"if,omitempty"`
	Env      map[string]string `yaml:"env,omitempty"`
	Steps    []Step            `yaml:"steps"`
}

// UnmarshalYAML applies custom logic for the unmarshalling of a job from YAML.
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

// Step is a step in a job.
type Step struct {
	Uses  string            `yaml:"uses,omitempty"`
	If    string            `yaml:"if,omitempty"`
	With  map[string]string `yaml:"with,omitempty"`
	Name  string            `yaml:"name,omitempty"`
	Shell string            `yaml:"shell,omitempty"`
	Run   string            `yaml:"run,omitempty"`
}

// Strategy describes execution parameter matrix for a job.
type Strategy struct {
	FailFast FailFast         `yaml:"fail-fast,omitempty" default:"true"`
	Matrix   SBMatrixStrategy `yaml:"matrix,omitempty"`
}

// UnmarshalYAML applies custom logic for the unmarshalling of a strategy from YAML.
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

// FailFast represents the fail-fast boolean.
type FailFast bool

// IsZero determines whether the boolean is in a "zero" state.
func (ff FailFast) IsZero() bool {
	// The FailFast defaults to true
	return bool(ff)
}

// SBMatrixStrategy is the job execution matrix.
type SBMatrixStrategy struct {
	Example []string          `yaml:"example,omitempty"`
	Runner  []string          `yaml:"runner,omitempty"`
	Include []SBMatrixInclude `yaml:"include,omitempty"`
}

// SBMatrixInclude is the include for the job execution matrix.
type SBMatrixInclude struct {
	Example string `yaml:"example,omitempty"`
	Test    string `yaml:"test"`
	Runner  string `yaml:"runner"`
}
