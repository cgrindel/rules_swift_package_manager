package swift

import (
	"encoding/json"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/swiftpkg"
)

// Module

// Module represents a Swift module mapped to a Bazel target.
type Module struct {
	Name               string
	C99name            string
	SrcType            swiftpkg.SourceType
	Label              *label.Label
	ModulemapLabel     *label.Label
	PkgIdentity        string
	ProductMemberships []string
}

// NewModule creates a new module.
func NewModule(
	name, c99name string,
	srcType swiftpkg.SourceType,
	bzlLabel *label.Label,
	modulemapLabel *label.Label,
	pkgIdentity string,
	pms []string,
) *Module {
	return &Module{
		Name:               name,
		C99name:            c99name,
		SrcType:            srcType,
		Label:              bzlLabel,
		PkgIdentity:        pkgIdentity,
		ProductMemberships: pms,
		ModulemapLabel:     modulemapLabel,
	}
}

// NewModuleFromLabelStruct is a convenience function because label.New returns a struct, not a
// pointer.
func NewModuleFromLabelStruct(
	name, c99name string,
	srcType swiftpkg.SourceType,
	bzlLabel label.Label,
	pkgIdentity string,
	pms []string,
) *Module {
	return NewModule(name, c99name, srcType, &bzlLabel, nil, pkgIdentity, pms)
}

// NewModuleFromTarget returns a module from the specified Swift target.
func NewModuleFromTarget(repoName, pkgIdentity string, t *swiftpkg.Target) (*Module, error) {
	lbl := BazelLabelFromTarget(repoName, t)
	var mml *label.Label
	if t.SwiftFileInfos.RequiresModulemap() {
		mml = ModulemapBazelLabelFromTargetLabel(lbl)
	}
	return NewModule(
		t.Name,
		t.C99name,
		t.SrcType,
		lbl,
		mml,
		pkgIdentity,
		t.ProductMemberships,
	), nil
}

// LabelStr returns the label string for module.
func (m *Module) LabelStr() LabelStr {
	return NewLabelStr(m.Label)
}

// Modules

// A Modules represents a slice of Swift modules.
type Modules []*Module

// LabelStrs returns the label strings for the modules.
func (modules Modules) LabelStrs() LabelStrs {
	labelStrs := make(LabelStrs, len(modules))
	for idx, m := range modules {
		labelStrs[idx] = NewLabelStr(m.Label)
	}
	return labelStrs
}

type moduleJSONData struct {
	Name               string              `json:"name"`
	C99name            string              `json:"c99name"`
	SrcType            swiftpkg.SourceType `json:"src_type"`
	Label              string              `json:"label"`
	ModulemapLabel     string              `json:"modulemap_label,omitempty"`
	PkgIdentity        string              `json:"package_identity"`
	ProductMemberships []string            `json:"product_memberships"`
}

// MarshalJSON customizes the marshalling of a module to JSON.
func (m *Module) MarshalJSON() ([]byte, error) {
	var pms []string
	if len(m.ProductMemberships) > 0 {
		pms = m.ProductMemberships
	} else {
		pms = []string{}
	}
	jd := &moduleJSONData{
		Name:               m.Name,
		C99name:            m.C99name,
		SrcType:            m.SrcType,
		Label:              m.Label.String(),
		PkgIdentity:        m.PkgIdentity,
		ProductMemberships: pms,
	}
	if m.ModulemapLabel != nil {
		jd.ModulemapLabel = m.ModulemapLabel.String()
	}
	return json.Marshal(&jd)
}

// UnmarshalJSON customizes the unmarshalling of a module from JSON.
func (m *Module) UnmarshalJSON(b []byte) error {
	var jd moduleJSONData
	if err := json.Unmarshal(b, &jd); err != nil {
		return err
	}
	l, err := label.Parse(jd.Label)
	if err != nil {
		return err
	}
	var mml *label.Label
	if jd.ModulemapLabel != "" {
		mmLabel, err := label.Parse(jd.ModulemapLabel)
		if err != nil {
			return err
		}
		mml = &mmLabel
	}
	newm := NewModule(jd.Name, jd.C99name, jd.SrcType, &l, mml, jd.PkgIdentity, jd.ProductMemberships)
	*m = *newm
	return nil
}
