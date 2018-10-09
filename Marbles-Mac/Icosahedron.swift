import Foundation
import SceneKit

class Icosahedron : SCNGeometry {
    // The golden ratio
    static let t = (1.0 + sqrt(5.0)) / 2.0;

    // These vertices represent three orthogonal rectangles
    // The corners of which define the 12 vertices of an icosahedron
    // We get the normalized vector so that our points are on the unit sphere
    static let vertices:[SCNVector3] = [
        SCNVector3(-1,  t, 0).normalized(),
        SCNVector3( 1,  t, 0).normalized(),
        SCNVector3(-1, -t, 0).normalized(),
        SCNVector3( 1, -t, 0).normalized(),

        SCNVector3(0, -1,  t).normalized(),
        SCNVector3(0,  1,  t).normalized(),
        SCNVector3(0, -1, -t).normalized(),
        SCNVector3(0,  1, -t).normalized(),

        SCNVector3( t,  0, -1).normalized(),
        SCNVector3( t,  0,  1).normalized(),
        SCNVector3(-t,  0, -1).normalized(),
        SCNVector3(-t,  0,  1).normalized()
    ]

    // Indices of points defining three orthogonal planes embedded in an icosahedron
    static let planeIndices:[Int32] = [
        7, 5,
        5, 4,
        4, 6,
        6, 7,

        0, 1,
        1, 3,
        3, 2,
        2, 0,

        10, 11,
        11, 9,
        9, 8,
        8, 10
    ]

    // Indices of points defining faces of each triangle in the convex hull
    static let faceIndices:[Int32] = [
        0, 11, 5,
        0, 5, 1,
        0, 1, 7,
        0, 7, 10,
        0, 10, 11,
        1, 5, 9,
        5, 11, 4,
        11, 10, 2,
        10, 7, 6,
        7, 1, 8,
        3, 9, 4,
        3, 4, 2,
        3, 2, 6,
        3, 6, 8,
        3, 8, 9,
        4, 9, 5,
        2, 4, 11,
        6, 2, 10,
        8, 6, 7,
        9, 8, 1
    ]

    // Indices of points defining a wireframe of the convex hull
    static let wireframeIndices:[Int32] = [
        0, 5,
        1, 0,
        1, 5,
        1, 7,
        1, 8,
        1, 9,
        2, 3,
        2, 4,
        2, 6,
        2, 10,
        2, 11,
        3, 6,
        3, 8,
        3, 9,
        4, 3,
        4, 5,
        4, 9,
        5, 9,
        6, 7,
        6, 8,
        6, 10,
        9, 8,
        8, 7,
        7, 0,
        10, 0,
        10, 7,
        10, 11,
        11, 0,
        11, 4,
        11, 5
    ]

    lazy var wireframe:SCNGeometry = {
        return self.createGeometry(
            Icosahedron.vertices, indices: Icosahedron.wireframeIndices,
            primitiveType: SCNGeometryPrimitiveType.Line)
    }()

    lazy var faces:SCNGeometry = {
        return self.createGeometry(
            Icosahedron.vertices, indices: Icosahedron.faceIndices,
            primitiveType: SCNGeometryPrimitiveType.Triangles)
    }()

    lazy var planes:SCNGeometry = {
        return self.createGeometry(
            Icosahedron.vertices, indices: Icosahedron.planeIndices,
            primitiveType: SCNGeometryPrimitiveType.Line)
    }()
}
