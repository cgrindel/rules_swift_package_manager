package stringslices

type MapFn func(value string) string

func Map(values []string, mapFn MapFn) []string {
	results := make([]string, len(values))
	for idx, val := range values {
		results[idx] = mapFn(val)
	}
	return results
}
