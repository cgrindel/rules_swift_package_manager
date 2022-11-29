package swiftcfg

type GenerateRulesMode int

const (
	SkipGenRulesMode GenerateRulesMode = iota
	SwiftPkgGenRulesMode
	SrcFileGenRulesMode
)
