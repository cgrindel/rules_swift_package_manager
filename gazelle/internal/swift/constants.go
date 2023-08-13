package swift

const (
	// swiftProtoSuffix is the suffix applied to the labels of all generated
	// swift_proto_library targets.
	swiftProtoSuffix = "_swift_proto"

	// swiftGRPCSuffix is the suffix applied to the labels of all generated
	// swift_grpc_library targets.
	swiftGRPCSuffix = "_swift_grpc"

	// SwiftProtoModuleNameKey is the key for the module name private
	// attribute for swift_proto_library and swift_grpc_library targets.
	SwiftProtoModuleNameKey = "_swift_proto_module_name"
)
