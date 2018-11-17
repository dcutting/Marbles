import SceneKit

struct Triangle: Equatable {

    let a: Patch.Vertex
    let b: Patch.Vertex
    let c: Patch.Vertex

    var vertices: [Patch.Vertex] {
        return [a, b, c]
    }

    var longestEdgeSq: FP {
        let ab = (a-b).lengthSq()
        let bc = (b-c).lengthSq()
        let ac = (a-c).lengthSq()
        return max(ab, bc, ac)
    }

    func normalised() -> Triangle {
        return Triangle(a: normalised(vertex: a),
                        b: normalised(vertex: b),
                        c: normalised(vertex: c))
    }

    private func normalised(vertex: Patch.Vertex) -> Patch.Vertex {
        if vertex.z > 1.0 {
            return Patch.Vertex(-vertex.x, -vertex.y, vertex.z)
        }
        return vertex
    }

    func distanceSq(from p: Patch.Vertex) -> FP {
        let pa = (p-a).lengthSq()
        let pb = (p-b).lengthSq()
        let pc = (p-c).lengthSq()
        return min(pa, pb, pc)
    }

    var centroid: Patch.Vertex {
        return (a + b + c) / 3.0
    }

    func facingFactor(to position: Patch.Vertex) -> FP {
        let normal = centroid.normalised()
        let normalisedPosition = position.normalised()
        return normalisedPosition.dot(of: normal)
    }
}

struct Patch {

    typealias Vertex = FP3
    typealias Colour = float3
    typealias Index = UInt32

    var vertices = [Vertex]()
    var colours = [Colour]()
    var indices = [Index]()
}
