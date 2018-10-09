import SceneKit

class Geometry : NSObject {

    // Creates a geometry object from given vertex, index and type data
    internal func createGeometry(vertices:[SCNVector3], indices:[Int32], primitiveType:SCNGeometryPrimitiveType) -> SCNGeometry {

        // Computed property that indicates the number of primitives to create based on primitive type
        var primitiveCount:Int {
            get {
                switch primitiveType {
                case SCNGeometryPrimitiveType.Line:
                    return indices.count / 2
                case SCNGeometryPrimitiveType.Point:
                    return indices.count
                case SCNGeometryPrimitiveType.Triangles,
                     SCNGeometryPrimitiveType.TriangleStrip:
                    return indices.count / 3
                }
            }
        }

        // Create the source and elements in the appropriate format
        let data = NSData(bytes: vertices, length: sizeof(SCNVector3) * vertices.count)
        let vertexSource = SCNGeometrySource(
            data: data, semantic: SCNGeometrySourceSemanticVertex,
            vectorCount: vertices.count, floatComponents: true, componentsPerVector: 3,
            bytesPerComponent: sizeof(Float), dataOffset: 0, dataStride: sizeof(SCNVector3))
        let indexData = NSData(bytes: indices, length: sizeof(Int32) * indices.count)
        let element = SCNGeometryElement(
            data: indexData, primitiveType: primitiveType,
            primitiveCount: primitiveCount, bytesPerIndex: sizeof(Int32))

        return SCNGeometry(sources: [vertexSource], elements: [element])
    }
}
