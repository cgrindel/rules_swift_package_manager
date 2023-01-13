package swift

const (
	LibraryRuleKind = "swift_library"
	BinaryRuleKind  = "swift_binary"
	TestRuleKind    = "swift_test"

	// Repository Rule
	SwiftPkgRuleKind      = "swift_package"
	LocalSwiftPkgRuleKind = "local_swift_package"
	HTTPArchiveRuleKind   = "http_archive"

	AliasRuleKind = "alias"
)

// IsSwiftRuleKind determines whether to provided rule kind is a Swift rule.
func IsSwiftRuleKind(ruleKind string) bool {
	switch ruleKind {
	case LibraryRuleKind, BinaryRuleKind, TestRuleKind:
		return true
	default:
		return false
	}
}
