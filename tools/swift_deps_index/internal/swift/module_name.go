package swift

import (
	"github.com/bazelbuild/bazel-gazelle/rule"
)

const (
	ModuleNameAttrName = "module_name"
)

// ModuleName returns the module name from a Swift rule declaration.
func ModuleName(r *rule.Rule) string {
	moduleName := r.AttrString(ModuleNameAttrName)
	if moduleName != "" {
		return moduleName
	}
	return r.Name()
}
