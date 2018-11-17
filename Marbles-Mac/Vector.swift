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

func midway(_ a: FP3, _ b: FP3) -> FP3 {

    let abx = (a.x + b.x) / 2.0
    let aby = (a.y + b.y) / 2.0
    let abz = (a.z + b.z) / 2.0

    return [abx, aby, abz]
}

func isIntersecting(_ triangle: Triangle, width: FP, height: FP, inset: FP) -> Bool {
    let minX = min(triangle.a.x, triangle.b.x, triangle.c.x)
    let maxX = max(triangle.a.x, triangle.b.x, triangle.c.x)
    let minY = min(triangle.a.y, triangle.b.y, triangle.c.y)
    let maxY = max(triangle.a.y, triangle.b.y, triangle.c.y)
    let overlapsX = minX <= width - inset && maxX >= inset
    let overlapsY = minY <= height - inset && maxY >= inset
    return overlapsX && overlapsY
}
