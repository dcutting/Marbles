//
//  CSG+SceneKit.swift
//  GameTest
//
//  Created by Nick Lockwood on 30/08/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

import SceneKit

private extension Data {
    mutating func append(_ int: UInt32) {
        var int = int
        append(UnsafeBufferPointer(start: &int, count: 1))
    }

    mutating func append(_ double: Double) {
        var float = Float(double)
        append(UnsafeBufferPointer(start: &float, count: 1))
    }

    mutating func append(_ vector: CSG.Vector) {
        append(vector.x)
        append(vector.y)
        append(vector.z)
    }
}

public extension SCNGeometry {
    convenience init(_ csg: CSG, materialLookup: ((CSG.Material) -> SCNMaterial)? = nil) {
        var elementData = [Data]()
        var vertexData = Data()
        var indicesByVertex = [CSG.Vertex: UInt32]()
        var _materials = [SCNMaterial]()
        for (material, polygons) in csg.polygonsByMaterial {
            var indexData = Data()
            func addVertex(_ vertex: CSG.Vertex) {
                if let index = indicesByVertex[vertex] {
                    indexData.append(index)
                    return
                }
                let index = UInt32(indicesByVertex.count)
                indicesByVertex[vertex] = index
                indexData.append(index)
                vertexData.append(vertex.position)
                vertexData.append(vertex.normal)
                vertexData.append(vertex.uv.x)
                vertexData.append(vertex.uv.y)
            }
            if let materialLookup = materialLookup {
                _materials.append(materialLookup(material))
            }
            for polygon in polygons {
                for triangle in polygon.tessellate() {
                    triangle.vertices.forEach(addVertex)
                }
            }
            elementData.append(indexData)
        }
        let vertexStride = 12 + 12 + 8
        let vertexCount = vertexData.count / vertexStride
        self.init(
            sources: [
                SCNGeometrySource(
                    data: vertexData,
                    semantic: .vertex,
                    vectorCount: vertexCount,
                    usesFloatComponents: true,
                    componentsPerVector: 3,
                    bytesPerComponent: 4,
                    dataOffset: 0,
                    dataStride: vertexStride
                ),
                SCNGeometrySource(
                    data: vertexData,
                    semantic: .normal,
                    vectorCount: vertexCount,
                    usesFloatComponents: true,
                    componentsPerVector: 3,
                    bytesPerComponent: 4,
                    dataOffset: 12,
                    dataStride: vertexStride
                ),
                SCNGeometrySource(
                    data: vertexData,
                    semantic: .texcoord,
                    vectorCount: vertexCount,
                    usesFloatComponents: true,
                    componentsPerVector: 2,
                    bytesPerComponent: 4,
                    dataOffset: 24,
                    dataStride: vertexStride
                )
            ],
            elements: elementData.map { indexData in
                SCNGeometryElement(
                    data: indexData,
                    primitiveType: .triangles,
                    primitiveCount: indexData.count / 12,
                    bytesPerIndex: 4
                )
            }
        )
        self.materials = _materials
    }

    convenience init(normals csg: CSG, scale: Double = 1) {
        var indexData = Data()
        var vertexData = Data()
        var indicesByVertex = [CSG.Vector: UInt32]()
        func addVertex(_ vertex: CSG.Vector) {
            if let index = indicesByVertex[vertex] {
                indexData.append(index)
                return
            }
            let index = UInt32(indicesByVertex.count)
            indicesByVertex[vertex] = index
            indexData.append(index)
            vertexData.append(vertex)
        }
        func addNormal(for vertex: CSG.Vertex) {
            addVertex(vertex.position)
            addVertex(vertex.position.plus(vertex.normal.times(scale)))
        }
        for polygon in csg.polygons {
            let vertices = polygon.vertices
            let v0 = vertices[0]
            for i in 2 ..< vertices.count {
                addNormal(for: v0)
                addNormal(for: vertices[i - 1])
                addNormal(for: vertices[i])
            }
        }
        self.init(
            sources: [
                SCNGeometrySource(
                    data: vertexData,
                    semantic: .vertex,
                    vectorCount: vertexData.count / 12,
                    usesFloatComponents: true,
                    componentsPerVector: 3,
                    bytesPerComponent: 4,
                    dataOffset: 0,
                    dataStride: 0
                ),
            ],
            elements: [
                SCNGeometryElement(
                    data: indexData,
                    primitiveType: .line,
                    primitiveCount: indexData.count / 8,
                    bytesPerIndex: 4
                )
            ]
        )
    }

    convenience init(_ path: CSG.Path) {
        var indexData = Data()
        var vertexData = Data()
        var indicesByPoint = [CSG.Point: UInt32]()
        func addPoint(_ point: CSG.Point) {
            if let index = indicesByPoint[point] {
                indexData.append(index)
                return
            }
            let index = UInt32(indicesByPoint.count)
            indicesByPoint[point] = index
            indexData.append(index)
            vertexData.append(point.x)
            vertexData.append(point.y)
        }
        var last: CSG.Point?
        for point in path.points {
            if let last = last, last != point {
                addPoint(last)
                addPoint(point)
            }
            last = point
        }
        self.init(
            sources: [
                SCNGeometrySource(
                    data: vertexData,
                    semantic: .vertex,
                    vectorCount: vertexData.count / 8,
                    usesFloatComponents: true,
                    componentsPerVector: 2,
                    bytesPerComponent: 4,
                    dataOffset: 0,
                    dataStride: 0
                ),
            ],
            elements: [
                SCNGeometryElement(
                    data: indexData,
                    primitiveType: .line,
                    primitiveCount: indexData.count / 8,
                    bytesPerIndex: 4
                )
            ]
        )
    }
}
