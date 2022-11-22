package jsonutils

import (
	"errors"
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
	return fmt.Sprintf("key '%v' not found", e.Key)
}

func IsMissingKeyError(err error) bool {
	var mke *MissingKeyError
	return errors.As(err, &mke)
}

// KeyTypeError

type KeyTypeError struct {
	mapKey
	unexpectedType
}

func NewKeyTypeError(key, expectedType string, actual any) *KeyTypeError {
	return &KeyTypeError{
		mapKey{Key: key},
		unexpectedType{
			ExpectedType: expectedType,
			ActualType:   fmt.Sprintf("%T", actual),
		},
	}
}

func (e *KeyTypeError) Error() string {
	return fmt.Sprintf(
		"key '%s' expected to be type '%s', but was type '%s'",
		e.Key, e.ExpectedType, e.ActualType)
}
