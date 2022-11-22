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

// func IsMissingKeyError(err error) bool {
// 	var mke *MissingKeyError
// 	return errors.As(err, &mke)
// }

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

// MarshalKeyError

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
