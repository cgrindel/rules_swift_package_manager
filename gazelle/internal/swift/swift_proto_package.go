package swift

import "github.com/bazelbuild/bazel-gazelle/language/proto"

const (
	// SwiftProtoPackageKey - Private attribute key used to augment generated swift_proto_library
	// rules with a SwiftProtoPackage.
	// This is used to create the import specs for swift_proto_library -> swift_proto_library dependencies.
	SwiftProtoPackageKey = "_swift_proto_package"
)

// SwiftProtoPackage - Holds information about the proto package from which a swift_proto_library was generated.
type SwiftProtoPackage struct {

	// The canonical absolute path to the directory containing both the proto_library and swift_proto_library.
	Dir string

	// The workspace-relative absolute path to the directory containing both the proto_library and swift_proto_library.
	Rel string

	// The proto package from the proto_library from which the swift_proto_library was generated.
	ProtoPackage proto.Package
}
