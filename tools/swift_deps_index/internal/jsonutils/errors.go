package jsonutils

import (
	"fmt"
)

type mapKey struct {
	Key string
}

type sliceIndex struct {
	Index int
}

type unexpectedType struct {
	ExpectedType string
	ActualType   string
}

// MissingKeyError

// A MissingKeyError is the error that is returned by functions in this package when a key is
// requrested and is not found.
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

// KeyTypeError

// A KeyTypeError is the error that is returned by functions in this package when key is requested,
// it exists, but is not of the expected type.
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

// KeyError

// A KeyError wraps an error that occurs when requesting a key value.
type KeyError struct {
	Err error
	mapKey
}

func NewKeyError(k string, err error) *KeyError {
	mk := mapKey{Key: k}
	return &KeyError{
		Err:    err,
		mapKey: mk,
	}
}

func (e *KeyError) Error() string {
	return fmt.Sprintf("error occurred processing '%v', %v", e.Key, e.Err)
}

func (e *KeyError) Unwrap() error {
	return e.Err
}

// IndexTypeError

// An IndexTypeError is the error that is returned when a value is requested for an index value in a
// slice and the value is not of the expected tpe.
type IndexTypeError struct {
	sliceIndex
	unexpectedType
}

func NewIndexTypeError(index int, expectedType string, actual any) *IndexTypeError {
	return &IndexTypeError{
		sliceIndex{Index: index},
		unexpectedType{
			ExpectedType: expectedType,
			ActualType:   fmt.Sprintf("%T", actual),
		},
	}
}

func (e *IndexTypeError) Error() string {
	return fmt.Sprintf(
		"index %d expected to be type '%s', but was type '%s'",
		e.Index, e.ExpectedType, e.ActualType)
}

// IndexOutOfBoundsError

// An IndexOutOfBoundsError is returned when the requested index is not valid.
type IndexOutOfBoundsError struct {
	sliceIndex
	ActualLen int
}

func NewIndexOutOfBoundsError(idx, actualLen int) *IndexOutOfBoundsError {
	return &IndexOutOfBoundsError{
		sliceIndex: sliceIndex{Index: idx},
		ActualLen:  actualLen,
	}
}

func (e *IndexOutOfBoundsError) Error() string {
	return fmt.Sprintf(
		"index %d out of bounds for slice with length %d",
		e.Index, e.ActualLen)
}
