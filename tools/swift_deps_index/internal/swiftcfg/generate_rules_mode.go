package swiftcfg

// A GenerateRulesMode is an enum for the mode for build file generation.
type GenerateRulesMode int

const (
	SkipGenRulesMode GenerateRulesMode = iota
	SwiftPkgGenRulesMode
	SrcFileGenRulesMode
)
