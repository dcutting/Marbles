import SceneKit

public typealias FP = Double
public typealias FP3 = double3

public func unitClamp(_ v: FP) -> FP {
    guard v > 0.0 else { return 0.0 }
    guard v < 1.0 else { return 1.0 }
    return v
}

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

extension Triangle {

    var centroid: Patch.Vertex {
        return (a + b + c) / 3.0
    }

    func facingFactor(to position: Patch.Vertex) -> FP {
        let normal = centroid.normalised()
        let normalisedPosition = position.normalised()
        return normalisedPosition.dot(of: normal)
    }
}

public func times(left: FP3, scalar: FP) -> FP3 {
    return [left[0] * scalar, left[1] * scalar, left[2] * scalar]
}

func scaledUnitClamp(_ t: FP, v0: FP, v1: FP) -> FP {
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

func isIntersecting(_ a: Patch.Vertex, _ b: Patch.Vertex, _ c: Patch.Vertex, width: FP, height: FP) -> Bool {
    let minX = min(a.x, b.x, c.x)
    let maxX = max(a.x, b.x, c.x)
    let minY = min(a.y, b.y, c.y)
    let maxY = max(a.y, b.y, c.y)
    let inset: FP = debug ? 100.0 : 0.0
    let overlapsX = minX <= width - inset && maxX >= inset
    let overlapsY = minY <= height - inset && maxY >= inset
    return overlapsX && overlapsY
}

func isNotZClipped(_ a: Patch.Vertex, _ b: Patch.Vertex, _ c: Patch.Vertex) -> Bool {
    if a.z > 1.0 && b.z > 1.0 && c.z > 1.0 {
        return false
    }
    if a.z < 0.0 && b.z < 0.0 && c.z < 0.0 {
        return false
    }
    let r = a.z >= 0.0 && a.z <= 1.0 ||  // TODO: || or &&?
            b.z >= 0.0 && b.z <= 1.0 ||
            c.z >= 0.0 && c.z <= 1.0
    if !r {
        print(a)
        print(b)
        print(c)
        print()
    }
    return r
}
