package pathdistance_test

import (
	"testing"

	"github.com/cgrindel/rules_swift_package_manager/tools/swift_deps_index/internal/pathdistance"
	"github.com/stretchr/testify/assert"
)

func TestGetPathAtDistance(t *testing.T) {
	tests := []struct {
		path string
		dist int
		wval string
	}{
		{path: "", dist: 3, wval: ""},
		{path: "foo/bar/hello", dist: 0, wval: "foo/bar/hello"},
		{path: "foo/bar/hello", dist: 1, wval: "foo/bar"},
		{path: "foo/bar/hello", dist: 2, wval: "foo"},
		{path: "foo/bar/hello", dist: 10, wval: ""},
	}
	for _, tc := range tests {
		actual := pathdistance.PathAt(tc.path, tc.dist)
		assert.Equal(t, tc.wval, actual)
	}
}

func TestDistanceFromPath(t *testing.T) {
	values := []string{"foo"}
	tests := []struct {
		path string
		wval int
	}{
		{path: "", wval: -1},
		{path: "chicken/bar/hello", wval: -1},
		{path: "chicken/bar/foo", wval: 0},
		{path: "chicken/foo/hello", wval: 1},
		{path: "foo/bar/hello", wval: 2},
	}
	for _, tc := range tests {
		actual := pathdistance.DistanceFrom(values, tc.path)
		assert.Equal(t, tc.wval, actual)
	}
}
