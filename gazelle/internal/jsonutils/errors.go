package jsonutils

import (
	"fmt"
)

type mapKey struct {
	Key string
}

type unexpectedType struct {
	ExpectedType string
	ActualType   string
}

// MissingKeyError

type MissingKeyError struct {
	mapKey
}

func NewMissingKeyError(key string) *MissingKeyError {
	return &MissingKeyError{
		mapKey{Key: key},
	}
}

func (e *MissingKeyError) Error() string {
	return fmt.Sprintf("map key '%v' is missing", e.Key)
}

// KeyTypeError

type KeyTypeError struct {
	mapKey
	unexpectedType
}

func NewKeyTypeError(key, expected string, actual any) *KeyTypeError {
	return &KeyTypeError{
		mapKey{Key: key},
		unexpectedType{
			ExpectedType: expected,
			ActualType:   fmt.Sprintf("%T", actual),
		},
	}
}

func (e *KeyTypeError) Error() string {
	return fmt.Sprintf(
		"map key '%s' expected to be '%s', but was '%s'",
		e.Key, e.ExpectedType, e.ActualType)
}
