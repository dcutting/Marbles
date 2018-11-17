import SceneKit

public typealias FP = Double
public typealias FP3 = double3

extension Patch.Vertex {

    func length() -> FP {
        return simd.length(self)
    }

    func lengthSq() -> FP {
        return simd.length_squared(self)
    }

    func normalised() -> FP3 {
        return simd.normalize(self)
    }

    func dot(of vector: Patch.Vertex) -> FP {
        return simd.dot(self, vector)
    }

    func cross(with vector: Patch.Vertex) -> Patch.Vertex {
        return simd.cross(self, vector)
    }

    func distance(to point: Patch.Vertex) -> FP {
        return simd.distance(self, point)
    }

    func midway(to: Patch.Vertex) -> Patch.Vertex {
        let abx = (x + to.x) / 2.0
        let aby = (y + to.y) / 2.0
        let abz = (z + to.z) / 2.0
        return [abx, aby, abz]
    }
}

public func unitClamp(_ v: FP) -> FP {
    guard v > 0.0 else { return 0.0 }
    guard v < 1.0 else { return 1.0 }
    return v
}

func interpolated(_ t: FP, v0: FP, v1: FP) -> FP {
    return (1 - t) * v0 + t * v1
}

func pow(_ base: UInt32, _ power: UInt32) -> UInt32 {
    var answer: UInt32 = 1
    for _ in 0..<power { answer *= base }
    return answer
}
