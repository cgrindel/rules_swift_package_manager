package swiftpkg

type ProductType int

const (
	UnknownProductType ProductType = iota
	ExecutableProductType
	LibraryProductType
	PluginProductType
)

type Product struct {
	Name    string
	Targets []string
	Type    ProductType
}
