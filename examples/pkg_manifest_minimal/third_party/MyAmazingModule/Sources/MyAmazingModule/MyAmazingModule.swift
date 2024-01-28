public class QuickSort {
    public init() {}

    public func sort(_ array: [Int]) -> [Int] {
        if array.count <= 1 { return array }

        let pivot = array[array.count/2]
        let less = array.filter { $0 < pivot }
        let equal = array.filter { $0 == pivot }
        let greater = array.filter { $0 > pivot }

        return sort(less) + equal + sort(greater)
    }
}