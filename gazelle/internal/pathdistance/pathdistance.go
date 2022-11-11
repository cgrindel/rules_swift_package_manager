package pathdistance

import (
	"path/filepath"

	"golang.org/x/exp/slices"
)

func PathAt(path string, distance int) string {
	if path == "" || distance <= 0 {
		return path
	}
	parent := filepath.Dir(path)
	return PathAt(parent, distance-1)
}

func DistanceFrom(values []string, path string, distance int) int {
	if path == "" {
		return -1
	}
	basename := filepath.Base(path)
	if slices.Contains(values, basename) {
		return distance
	}
	dir := filepath.Dir(path)
	return DistanceFrom(values, dir, distance+1)
}
