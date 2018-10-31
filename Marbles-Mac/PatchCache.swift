import Foundation

class PatchCache {

    private var cache = [String: Patch]()
    private let lock = DispatchQueue(label: "lock", qos: .userInteractive, attributes: .concurrent)

    func read(_ name: String) -> Patch? {
        return lock.sync {
            return cache[name]
        }
    }

    func write(_ name: String, patch: Patch) {
        lock.async(flags: .barrier) {
            self.cache[name] = patch
        }
    }

    func count() -> Int {
        return lock.sync {
            return cache.count
        }
    }
}
