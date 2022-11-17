package swift

import "github.com/bazelbuild/bazel-gazelle/rule"

const (
	ModuleNameAttrName = "module_name"
)

func ModuleName(r *rule.Rule) string {
	moduleName := r.AttrString(ModuleNameAttrName)
	if moduleName != "" {
		return moduleName
	}
	return r.Name()
}
