import SceneKit

struct Triangle: Equatable {
    let a: Patch.Vertex
    let b: Patch.Vertex
    let c: Patch.Vertex

    var vertices: [Patch.Vertex] {
        return [a, b, c]
    }

    var longestEdge: FP {
        let ab = (a-b).length()
        let bc = (b-c).length()
        let ac = (a-c).length()
        return max(ab, bc, ac)
    }

    func normalised() -> Triangle {
        return Triangle(a: normalise(a), b: normalise(b), c: normalise(c))
    }

    private func normalise(_ vertex: Patch.Vertex) -> Patch.Vertex {
        if vertex.z > 1.0 {
            return Patch.Vertex(-vertex.x, -vertex.y, vertex.z)
        }
        return vertex
    }

    func distance(from p: Patch.Vertex) -> FP {
        let pa = (p-a).length()
        let pb = (p-b).length()
        let pc = (p-c).length()
        return min(pa, pb, pc)
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
