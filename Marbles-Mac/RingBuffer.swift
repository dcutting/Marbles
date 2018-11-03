import Foundation

class RingBuffer<T> {

    private let size: Int
    private var buffer: [T?]
    private var head = 0
    private var tail = 0
    private let lock = DispatchQueue(label: "lock", qos: .userInteractive, attributes: .concurrent)

    init(size: Int) {
        self.size = size
        buffer = [T?](repeating: nil, count: size)
    }

    func read() -> T? {
        return lock.sync(flags: .barrier) {
            guard let op = buffer[head] else { return nil }
            buffer[head] = nil
            head = (head + 1) % size
//            print("read: \(head), \(tail), \(_count)")
            return op
        }
    }

    func append(_ op: T) -> T? {
        return lock.sync(flags: .barrier) {
            self.buffer[self.tail] = op
            self.tail = (self.tail + 1) % self.size
            var bumped: T?
            if self.tail == self.head {
                self.head = (self.head + 1) % self.size
                bumped = self.buffer[self.tail]
            }
//            print("append: \(head), \(tail), \(_count)")
            return bumped
        }
    }

    func count() -> Int {
        return lock.sync {
            return _count
        }
    }

    private var _count: Int {
        return tail < head ? tail - head + size : tail - head
    }
}
