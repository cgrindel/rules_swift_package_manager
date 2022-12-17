package pathdistance

import (
	"path/filepath"

	"github.com/cgrindel/swift_bazel/gazelle/internal/stringslices"
)

func PathAt(path string, distance int) string {
	if path == "" || distance <= 0 {
		return path
	}
	parent := parentDir(path)
	return PathAt(parent, distance-1)
}

func DistanceFrom(values []string, path string) int {
	return doDistanceFrom(values, path, 0)
}

func doDistanceFrom(values []string, path string, distance int) int {
	if path == "" {
		return -1
	}
	basename := filepath.Base(path)
	if stringslices.Contains(values, basename) {
		return distance
	}
	parent := parentDir(path)
	return doDistanceFrom(values, parent, distance+1)
}

func parentDir(path string) string {
	parent := filepath.Dir(path)
	if parent == "." {
		parent = ""
	}
	return parent
}
