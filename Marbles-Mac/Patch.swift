import SceneKit

struct Patch {

    typealias Vertex = FP3
    typealias Colour = float3
    typealias Index = UInt32

    var vertices = [Vertex]()
    var colours = [Colour]()
    var indices = [Index]()
}

let white: Patch.Colour = [1.0, 1.0, 1.0]
let red: Patch.Colour = [1.0, 0.0, 0.0]
let yellow: Patch.Colour = [1.0, 1.0, 0.0]
let cyan: Patch.Colour = [0.0, 1.0, 1.0]
let magenta: Patch.Colour = [1.0, 0.0, 1.0]
let grey: Patch.Colour = [0.4, 0.4, 0.4]
