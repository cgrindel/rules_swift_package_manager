package swift

import "path/filepath"

// FilterFiles returns a list of Swift source files excluding `Package.swift`.
func FilterFiles(paths []string) []string {
	var results []string
	for _, path := range paths {
		base := filepath.Base(path)
		ext := filepath.Ext(base)
		if ext == ".swift" && base != "Package.swift" {
			results = append(results, path)
		}
	}
	return results
}
