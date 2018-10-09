import SceneKit

class IcoSphere : Geometry {
    // Initialize the data to the Icosahedron
    var faceIndices:[Int32] = Icosahedron.faceIndices
    var vertices:[SCNVector3] = Icosahedron.vertices
    var wireframeIndices:[Int32] = Icosahedron.wireframeIndices

    required init(subdivisions:Int) {
        // Map string representations to indices (used to avoid duplicate vertices)
        var map:[String:Int32] = [String:Int32]()

        // For as many subdivisions do the following...
        for _ in 0..<subdivisions {
            // Copy of the face indices because the list is re-created on each iteration
            let faces = faceIndices
            wireframeIndices = []
            faceIndices = []

            // Loop through each of the faces (triangles)
            for var i = 0; i <= faces.count - 3; i+=3 {
                // Make a reference to each vertex index in a triangle
                let vertexIndex1 = Int(faces[i])
                let vertexIndex2 = Int(faces[i+1])
                let vertexIndex3 = Int(faces[i+2])

                // Make a reference to each of the actual vertices
                // These three vertices make up the lines of a triangle
                let v1 = vertices[vertexIndex1]
                let v2 = vertices[vertexIndex2]
                let v3 = vertices[vertexIndex3]

                // Get the midpoint between each of the lines of the triangle
                // Combined with the three vertices above, these are the six points of a subdivided triangle
                let a = SCNVector3.getMidpoint(v1, v2: v2).normalized()
                let b = SCNVector3.getMidpoint(v2, v2: v3).normalized()
                let c = SCNVector3.getMidpoint(v3, v2: v1).normalized()

                // Add new vertices to list only if they don't already exist
                var indices:[Int32] = [Int32(vertexIndex1), Int32(vertexIndex2), Int32(vertexIndex3)]
                for v in [a, b, c] {
                    if let idx = map[v.string()] {
                        indices.append(idx)
                    } else {
                        let idx:Int32 = Int32(vertices.count)
                        vertices.append(v)
                        indices.append(idx)
                        map[v.string()] = idx
                    }
                }

                // Create new faces
                faceIndices.appendContentsOf([
                    indices[0], indices[3], indices[5],
                    indices[1], indices[4], indices[3],
                    indices[2], indices[5], indices[4],
                    indices[3], indices[4], indices[5]
                    ])

                // Create new pairs of points for the wireframe
                wireframeIndices.appendContentsOf([
                    indices[0], indices[3],
                    indices[3], indices[5],
                    indices[5], indices[0],

                    indices[3], indices[1],
                    indices[1], indices[4],
                    indices[4], indices[3],

                    indices[4], indices[2],
                    indices[2], indices[5],
                    indices[5], indices[4],

                    indices[3], indices[4],
                    indices[4], indices[5],
                    indices[5], indices[3]
                    ])
            }
        }
    }

    lazy var wireframe:SCNGeometry = {
        return self.createGeometry(
            vertices: self.vertices, indices: self.wireframeIndices,
            primitiveType: SCNGeometryPrimitiveType.line)
    }()

    lazy var faces:SCNGeometry = {
        return self.createGeometry(
            vertices: self.vertices, indices: self.faceIndices,
            primitiveType: SCNGeometryPrimitiveType.triangles)
    }()

    lazy var points:SCNGeometry = {
        return self.createGeometry(
            vertices: self.vertices, indices: self.wireframeIndices, primitiveType: SCNGeometryPrimitiveType.point)
    }()
}
