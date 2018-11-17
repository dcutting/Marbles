import SceneKit

public typealias FP3 = double3

extension Patch.Vertex {

    func length() -> FP {
        return simd.length(self)
    }

    func lengthSq() -> FP {
        return simd.length_squared(self)
    }

    func normalised() -> Patch.Vertex {
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
