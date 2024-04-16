package swift

const (
	LibraryRuleKind      = "swift_library"
	ProtoLibraryRuleKind = "swift_proto_library"
	BinaryRuleKind       = "swift_binary"
	TestRuleKind         = "swift_test"

	// Repository Rule
	SwiftPkgRuleKind      = "swift_package"
	LocalSwiftPkgRuleKind = "local_swift_package"
	HTTPArchiveRuleKind   = "http_archive"

	AliasRuleKind = "alias"
)

// IsSwiftRuleKind determines whether to provided rule kind is a Swift rule.
func IsSwiftRuleKind(ruleKind string) bool {
	switch ruleKind {
	case LibraryRuleKind, ProtoLibraryRuleKind, BinaryRuleKind, TestRuleKind:
		return true
	default:
		return false
	}
}
