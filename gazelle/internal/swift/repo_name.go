package swift

import (
	"fmt"
	"path"
	"strings"
)

func RepoName(url string) (string, error) {
	if url == "" {
		return "", fmt.Errorf("URL cannot be empty string")
	}
	parts := strings.Split(url, "/")
	if partsLen := len(parts); partsLen >= 2 {
		parts = parts[len(parts)-2:]
	}

	// Normalize parts
	for idx, p := range parts {
		parts[idx] = strings.ReplaceAll(p, "-", "_")
	}

	// Remove the extension from the last part of the URL
	lastidx := len(parts) - 1
	lastPart := parts[lastidx]
	if ext := path.Ext(lastPart); ext != "" {
		parts[lastidx] = strings.TrimSuffix(lastPart, ext)
	}

	// Put parts back together
	return strings.Join(parts, "_"), nil
}
