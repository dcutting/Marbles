import SceneKit

struct Triangle {
    let a: Patch.Vertex
    let b: Patch.Vertex
    let c: Patch.Vertex
}

struct Patch {

    typealias Vertex = FP3
    typealias Colour = float3
    typealias Index = UInt32

    var vertices = [Vertex]()
    var colours = [Colour]()
    var indices = [Index]()
}
