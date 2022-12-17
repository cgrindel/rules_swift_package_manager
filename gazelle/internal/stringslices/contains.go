package stringslices

import (
	"sort"
)

func Contains(values []string, target string) bool {
	for _, v := range values {
		if v == target {
			return true
		}
	}
	return false
}

// Performs binary search for the target. The values must be sorted in ascending order.
func SortedContains(values []string, target string) bool {
	idx := sort.SearchStrings(values, target)
	valuesLen := len(values)
	if idx < valuesLen {
		return values[idx] == target
	}
	return false
}
