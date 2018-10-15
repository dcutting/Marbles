import SceneKit

class Quadtree {

    let rootFaceIndex: UInt32
    var corners: [float3]
    var depth: UInt32 = 0
    var node: SCNNode?
    var subtrees = [Quadtree]()

    init(rootFaceIndex: UInt32, corners: [float3]) {
        self.rootFaceIndex = rootFaceIndex
        self.corners = corners
    }

    var hasChildren: Bool {
        return !subtrees.isEmpty
    }
}
