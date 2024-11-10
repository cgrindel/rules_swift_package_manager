package updmarker

import (
	"fmt"
	"strings"
)

type Updater struct {
	StartMarker string
	EndMarker   string
}

func NewUpdater(startMarker, endMarker string) *Updater {
	return &Updater{
		StartMarker: startMarker,
		EndMarker:   endMarker,
	}
}

func (u *Updater) UpdateString(original, snippet string, appendIfNotFound bool) (string, error) {
	var newContent string
	origLen := len(original)
	startIdx := strings.Index(original, u.StartMarker)
	endIdx := strings.Index(original, u.EndMarker)
	if startIdx < 0 && endIdx < 0 {
		if !appendIfNotFound {
			return original, nil
		}
		startIdx = origLen
	} else if startIdx >= 0 && endIdx >= 0 {
		endIdx += len(u.EndMarker)
	} else if startIdx > endIdx {
		return "", fmt.Errorf("the start and end markers appear to be out of order")
	} else if startIdx < 0 {
		return "", fmt.Errorf("found the end marker, but did not find the start marker")
	} else if endIdx < 0 {
		return "", fmt.Errorf("found the start marker, but did not find the end marker")
	}
	appendSnippet := func(runes []rune) []rune {
		runes = append(runes, []rune(u.StartMarker)...)
		runes = append(runes, []rune(snippet)...)
		runes = append(runes, []rune(u.EndMarker)...)
		return runes
	}
	newRunes := make([]rune, 0, origLen+len(snippet))
	for byteIdx, r := range original {
		if byteIdx < startIdx || (endIdx >= 0 && byteIdx >= endIdx) {
			newRunes = append(newRunes, r)
		} else if byteIdx == startIdx {
			newRunes = appendSnippet(newRunes)
		}
	}
	if startIdx == origLen {
		newRunes = appendSnippet(newRunes)
	}
	newContent = string(newRunes)
	return newContent, nil
}
