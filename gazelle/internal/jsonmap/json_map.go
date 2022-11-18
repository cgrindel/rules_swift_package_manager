package jsonmap

import "log"

// type jsonMap map[string]any
// type jsonMap map[string]interface{}

func String(jm map[string]any, k string) (string, bool) {
	rawValue, ok := jm[k]
	if !ok {
		return "", false
	}
	switch t := rawValue.(type) {
	case string:
		return rawValue.(string), true
	default:
		log.Println("Expected string for key %v, but was %v", k, t)
		return "", false
	}
}
