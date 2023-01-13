package stringslices

// A MapFn represents a function for mapping/converting string slice values another string value.
type MapFn func(value string) string

// Map creates a new slice of strings where the value for each string is the result of applying the
// map function to each value in the original slice.
func Map(values []string, mapFn MapFn) []string {
	results := make([]string, len(values))
	for idx, val := range values {
		results[idx] = mapFn(val)
	}
	return results
}
