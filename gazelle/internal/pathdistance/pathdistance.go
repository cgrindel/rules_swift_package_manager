// Package pathdistance provides utility functions that calculate distances and extract path values
// using distance values.
//
// A path distance represents the number of directory levels from the end of a path to a parent
// directory. For instance, for the path `foo/bar/baz`, the following are the path distance values
// for different components:
//
//	baz: 0
//	bar: 1
//	foo: 2
package pathdistance

import (
	"path/filepath"

	"golang.org/x/exp/slices"
)

// PathAt returns the remaining path given a path distance.
func PathAt(path string, distance int) string {
	if path == "" || distance <= 0 {
		return path
	}
	parent := parentDir(path)
	return PathAt(parent, distance-1)
}

// DistanceFrom determines the path distance for any of the provided values. In other words, if any
// of the values are an element of the path, it returns the distance to that match.
func DistanceFrom(values []string, path string) int {
	return doDistanceFrom(values, path, 0)
}

func doDistanceFrom(values []string, path string, distance int) int {
	if path == "" {
		return -1
	}
	basename := filepath.Base(path)
	if slices.Contains(values, basename) {
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
