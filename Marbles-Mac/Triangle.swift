import SceneKit

struct Triangle: Equatable {

    let a: Patch.Vertex
    let b: Patch.Vertex
    let c: Patch.Vertex

    var vertices: [Patch.Vertex] {
        return [a, b, c]
    }

    var centroid: Patch.Vertex {
        return (a + b + c) / 3.0
    }

    var longestEdgeSq: FP {
        let ab = (a-b).lengthSq()
        let bc = (b-c).lengthSq()
        let ac = (a-c).lengthSq()
        return max(ab, bc, ac)
    }

    func distanceSq(from p: Patch.Vertex) -> FP {
        let pa = (p-a).lengthSq()
        let pb = (p-b).lengthSq()
        let pc = (p-c).lengthSq()
        return min(pa, pb, pc)
    }

    func facingFactor(to position: Patch.Vertex) -> FP {
        let normal = centroid.normalised()
        let normalisedPosition = position.normalised()
        return normalisedPosition.dot(of: normal)
    }

    func isIntersecting(width: FP, height: FP, inset: FP) -> Bool {
        let minX = min(a.x, b.x, c.x)
        let maxX = max(a.x, b.x, c.x)
        let minY = min(a.y, b.y, c.y)
        let maxY = max(a.y, b.y, c.y)
        let overlapsX = minX <= width - inset && maxX >= inset
        let overlapsY = minY <= height - inset && maxY >= inset
        return overlapsX && overlapsY
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
}
