package reslog

import (
	"os"
)

// ResolutionLogger

type ResolutionLogger interface {
	// Log the rule resolution
	Log(rr *RuleResolution) error

	// Close the log
	Close() error
}

// LogToFile

func LogToFile(path string) (ResolutionLogger, error) {
	file, err := os.Create(path)
	if err != nil {
		return nil, err
	}
	return &fileLogger{
		file: file,
	}, nil
}

type fileLogger struct {
	file *os.File
}

func (fl *fileLogger) Log(rr *RuleResolution) error {
	// TODO(chuck): IMPLEMENT ME!
	return nil
}

func (fl *fileLogger) Close() error {
	return fl.file.Close()
}

// Noop Logger

func NoopLogger() ResolutionLogger {
	return &noopLogger{}
}

type noopLogger struct{}

func (nl *noopLogger) Log(rr *RuleResolution) error {
	// Do nothing
	return nil
}

func (nl *noopLogger) Close() error {
	return nil
}
