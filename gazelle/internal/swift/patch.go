package swift

import "gopkg.in/yaml.v3"

// Patch represents the parameters needed to patch a Swift package.
type Patch struct {
	Files   []string `json:"files" yaml:"files"`
	Args    []string `json:"args,omitempty" yaml:"args,omitempty"`
	Cmds    []string `json:"cmds,omitempty" yaml:"cmds,omitempty"`
	WinCmds []string `json:"win_cmds,omitempty" yaml:"win_cmds,omitempty"`
	Tool    string   `json:"tool,omitempty" yaml:"tool,omitempty"`
}

// // PatchDirective represents the patch information for a Swift package.
// type PatchDirective struct {
// 	Identity string `yaml:"identity"`
// 	Patch    `yaml:",inline"`
// }

// func NewPatchDirectiveFromYAML(yamlStr string) (*PatchDirective, error) {
// 	var patchDir PatchDirective
// 	err := yaml.Unmarshal([]byte(yamlStr), &patchDir)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return &patchDir, nil
// }

// NewPatchesFromYAML reads the provided YAML returning a map of patches organized by Swift package
// identity.
func NewPatchesFromYAML(b []byte) (map[string]*Patch, error) {
	var patches map[string]*Patch
	err := yaml.Unmarshal(b, &patches)
	if err != nil {
		return nil, err
	}
	return patches, nil
}

// func NewPatchDirectivesFromYAML(b []byte) ([]*PatchDirective, error) {
// 	var patches []*PatchDirective
// 	err := yaml.Unmarshal(b, &patches)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return patches, nil
// }
