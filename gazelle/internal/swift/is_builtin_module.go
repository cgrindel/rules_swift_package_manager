package swift

// The list of frameworks is found in builtin_modules.go.
var allBuiltInModules = macosFrameworks.Union(iosFrameworks)

// IsBuiltInModule determines if the module is built into the Swift standard library.
func IsBuiltInModule(name string) bool {
	return allBuiltInModules.Contains(name)
}
