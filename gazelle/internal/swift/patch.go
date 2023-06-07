package swift

import "gopkg.in/yaml.v3"

type Patch struct {
	Args    []string `json:"args" yaml:"args"`
	Cmds    []string `json:"cmds" yaml:"cmds"`
	WinCmds []string `json:"win_cmds" yaml:"win_cmds"`
	Tool    string   `json:"tool" yaml:"tool"`
	Files   []string `json:"files" yaml:"files"`
}

type PatchDirective struct {
	Identity string `yaml:"identity"`
	Patch    `yaml:",inline"`
}

func NewPatchDirectiveFromYAML(yamlStr string) (*PatchDirective, error) {
	var patchDir PatchDirective
	err := yaml.Unmarshal([]byte(yamlStr), &patchDir)
	if err != nil {
		return nil, err
	}
	return &patchDir, nil
}
