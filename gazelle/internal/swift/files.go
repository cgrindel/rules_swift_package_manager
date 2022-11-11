package swift

import "path/filepath"

func FilterFiles(paths []string) []string {
	var results []string
	for _, path := range paths {
		ext := filepath.Ext(path)
		if ext == ".swift" {
			results = append(results, path)
		}
	}
	return results
}
