import MyAmazingModule

public class ComplexClass {
    var name: String
    var age: Int
    var favoriteColors: [String]

    public init(name: String, age: Int, favoriteColors: [String]) {
        self.name = name
        self.age = age
        self.favoriteColors = favoriteColors
    }

    public func greet() -> String {
        return "Hello, my name is \(name) and I'm \(age) years old."
    }

    public func addFavoriteColor(color: String) {
        favoriteColors.append(color)
    }

    public func removeFavoriteColor(color: String) {
        favoriteColors.removeAll { $0 == color }
    }

    public func sortFavoriteColors() {
        let colorCodes = favoriteColors.map { $0.hashValue }
        let sortedColorCodes = MyAmazingModule.QuickSort().sort(colorCodes)
        favoriteColors = sortedColorCodes.map { String(describing: $0) }
    }
}
