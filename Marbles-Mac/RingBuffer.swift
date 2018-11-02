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
        return lock.sync {
            guard let op = buffer[head] else { return nil }
            buffer[head] = nil
            head = (head + 1) % size
            if head == tail {
                tail = (tail + 1) % size
            }
            return op
        }
    }

    func append(_ op: T) -> T? {
        return lock.sync(flags: .barrier) {
            self.buffer[self.tail] = op
            self.tail = (self.tail + 1) % self.size
//            print(head, tail)
            if self.tail == self.head {
                self.head = (self.head + 1) % self.size
                return self.buffer[self.tail]
            }
            return nil
        }
    }

    func count() -> Int {
        return lock.sync {
            return tail < head ? tail - head + size : tail - head
        }
    }
}
