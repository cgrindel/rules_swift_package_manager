package swift

const (
	LibraryRuleKind = "swift_library"
	BinaryRuleKind = "swift_binary"
	TestRuleKind = "swift_test"
 )

func IsSwiftRuleKind(ruleKind string) bool {
	switch ruleKind {
	case LibraryRuleKind, BinaryRuleKind, TestRuleKind:
		return true
	default:
		return false
	}
}
