import SceneKit

struct Patch {

    typealias Vertex = FP3
    typealias Colour = float3
    typealias Index = UInt32

    let vertices: [Vertex]
    let colours: [Colour]
    let indices: [Index]
}
