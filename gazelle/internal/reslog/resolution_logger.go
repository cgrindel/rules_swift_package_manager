package reslog

import (
	"bufio"
	"io"

	"gopkg.in/yaml.v2"
)

// ResolutionLogger

type ResolutionLogger interface {
	// Log the rule resolution
	Log(rr *RuleResolution) error

	// Flush the log
	Flush() error
}

// Log to Writer

func NewLoggerFromWriter(w io.Writer) ResolutionLogger {
	bw := bufio.NewWriter(w)
	return &writerLogger{writer: bw}
}

type writerLogger struct {
	writer *bufio.Writer
}

func (wl *writerLogger) Log(rr *RuleResolution) error {
	rrs := rr.Summary()
	b, err := yaml.Marshal(&rrs)
	if err != nil {
		return err
	}
	if _, err = wl.writer.Write(b); err != nil {
		return err
	}
	return nil
}

func (wl *writerLogger) Flush() error {
	return wl.writer.Flush()
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

func (nl *noopLogger) Flush() error {
	return nil
}
