import SceneKit

func makeGeometry(patch: Patch, asWireframe: Bool) -> SCNGeometry {
    let start = DispatchTime.now()
    let vertices = patch.vertices.map { SCNVector3($0[0], $0[1], $0[2]) }
    let verticesSource = SCNGeometrySource(vertices: vertices)
    var sources = [verticesSource]
    if !asWireframe {
        let coloursData = NSData(bytes: patch.colours,
                                 length: MemoryLayout<float3>.size * patch.colours.count)
        let coloursSource = SCNGeometrySource(data: coloursData as Data,
                                              semantic: .color,
                                              vectorCount: patch.colours.count,
                                              usesFloatComponents: true,
                                              componentsPerVector: 3,
                                              bytesPerComponent: MemoryLayout<Float>.size,
                                              dataOffset: 0,
                                              dataStride: MemoryLayout<float3>.size)
        sources.append(coloursSource)
    }
    let indicesElement = SCNGeometryElement(indices: patch.indices, primitiveType: .triangles)
    let geometry = SCNGeometry(sources: sources, elements: [indicesElement])
    if debug {
        let stop = DispatchTime.now()
        print("      Made geometry \(stop.uptimeNanoseconds - start.uptimeNanoseconds)")
    }
    return geometry
}
