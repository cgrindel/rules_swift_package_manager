package gazelle

const swiftLibraryRuleKind = "swift_library"
const swiftBinaryRuleKind = "swift_binary"
const swiftTestRuleKind = "swift_test"

func isSwiftRuleKind(ruleKind string) bool {
	switch ruleKind {
	case swiftLibraryRuleKind, swiftBinaryRuleKind, swiftTestRuleKind:
		return true
	default:
		return false
	}
}
