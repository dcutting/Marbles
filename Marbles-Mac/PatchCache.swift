import Foundation

class PatchCache<T> {

    private var cache = [String: T]()
    private let lock = DispatchQueue(label: "lock", qos: .userInteractive, attributes: .concurrent)

    func read(_ name: String) -> T? {
        return lock.sync {
            return cache[name]
        }
    }

    func write(_ name: String, patch: T) {
        lock.async(flags: .barrier) {
            self.cache[name] = patch
        }
    }

    func remove(_ name: String) -> Int {
        return lock.sync(flags: .barrier) {
            cache.removeValue(forKey: name)
            return cache.count
        }
    }

    func removeAll() {
        lock.sync(flags: .barrier) {
            cache.removeAll()
        }
    }

    func count() -> Int {
        return lock.sync {
            return cache.count
        }
    }
}
