import Foundation

struct PatchOp {
    let op: () -> Void
    let name: String
}

struct PrioritisedOp {
    let priority: Double
    let op: PatchOp
}

class PatchBuffer {

    private var priorityBuffer = [PrioritisedOp]()
    private let reader: DispatchQueue
    private let fast: DispatchQueue
    private let queued = PatchCache<Bool>()
    private let wip = PatchCache<Bool>()
    private let concurrentPatches = 12

    init() {
        self.reader = DispatchQueue(label: "reader", qos: .userInitiated, attributes: [])
        self.fast = DispatchQueue(label: "fast", qos: .default, attributes: .concurrent)
        pollRingBuffer()
    }

    private func pollRingBuffer() {
        reader.asyncAfter(deadline: .now() + 0.08) {
            let queuedCount = self.queued.count()
            let wipCount = self.wip.count()
            let toDo = max(0, self.concurrentPatches - wipCount)
            self.priorityBuffer.sort { a, b in
                a.priority < b.priority
            }
            let bufferCount = self.priorityBuffer.count
            let willDo = min(toDo, bufferCount)
            let ops = self.priorityBuffer.prefix(willDo)
            self.priorityBuffer.removeFirst(willDo)
            ops.forEach { op in
                self.fast.async(execute: op.op.op)
            }
            if debug {
                print("\(queuedCount), \(wipCount): \(ops.map { op in op.op.name })")
            }
            self.pollRingBuffer()
        }
    }

    func calculate(_ name: String, triangle: Triangle, subdivisions: UInt32, priority: Double, calculator: PatchCalculator, completion: @escaping (Patch) -> Void) {

        guard !isCalculating(name, subdivisions: subdivisions) else { return }

        let opName = "\(name)-\(subdivisions)"
        queued.write(opName, patch: true)

        let op = PatchOp(op: {
            self.reader.sync {
                _ = self.queued.remove(opName)
                self.wip.write(opName, patch: true)
            }
            let patch = calculator.subdivide(triangle: triangle, subdivisionLevels: subdivisions)
            completion(patch)
            self.reader.sync {
                _ = self.wip.remove(opName)
            }
        }, name: opName)

        let prioritisedOp = PrioritisedOp(priority: priority, op: op)

        reader.async {
            self.priorityBuffer.append(prioritisedOp)
        }
    }

    func clearBuffer() {
        reader.async {
            self.queued.removeAll()
            self.priorityBuffer.removeAll()
        }
    }

    func isCalculating(_ name: String, subdivisions: UInt32) -> Bool {
        return reader.sync {
            let opName = "\(name)-\(subdivisions)"
            let isInProgress = wip.read(opName) ?? false
            let isQueued = queued.read(opName) ?? false
            return isInProgress || isQueued
        }
    }
}
