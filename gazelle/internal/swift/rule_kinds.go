package swift

const (
	LibraryRuleKind = "swift_library"
	BinaryRuleKind  = "swift_binary"
	TestRuleKind    = "swift_test"

	// Repository Rule
	SwiftPkgRuleKind = "swift_package"
)

func IsSwiftRuleKind(ruleKind string) bool {
	switch ruleKind {
	case LibraryRuleKind, BinaryRuleKind, TestRuleKind:
		return true
	default:
		return false
	}
}
