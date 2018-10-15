import AppKit
import QuartzCore
import SceneKit
import SceneKit.ModelIO
import ModelIO

let wireframe = false
let seed = 3156
let octaves = 10
let width: CGFloat = 20.0
let frequency = 0.04
let persistence = 0.6
let lacunarity = 2.1
var amplitude: Double = Double(width / 4.0)

let subdivisionsPerNode = 6
let quadtreeDepth = 3
let smoothing = 0
let levels = 0
let iciness: CGFloat = 150.0

let halfWidth: CGFloat = width / 2.0
let halfAmplitude: Double = amplitude / 2.0

class MarbleViewController: NSViewController {

    let scene = SCNScene()
    let terrainNode = SCNNode()
    let terrainNoise: Noise
    let allocator = MDLMeshBufferDataAllocator()

    let terrainQueue = DispatchQueue(label: "terrain", qos: .userInteractive, attributes: .concurrent)

    required init?(coder: NSCoder) {
        let sourceNoise = GradientNoise3D(amplitude: amplitude, frequency: frequency, seed: seed)
        terrainNoise = FBM(sourceNoise, octaves: octaves, persistence: persistence, lacunarity: lacunarity)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scene.background.contents = NSImage(named: "tycho")!

        let light = SCNLight()
        light.type = .directional
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.look(at: SCNVector3())
        lightNode.position = SCNVector3(x: 0, y: 10*width, z: 10*width)
        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 200)))
        scene.rootNode.addChildNode(lightNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.3, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.showsStatistics = true

        makeWater()
//        makeClouds()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.makeRoot()
        }

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers.insert(clickGesture, at: 0)
        scnView.gestureRecognizers = gestureRecognizers
    }

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
    }

    private func makeWater() {
        let noise = GradientNoise3D(amplitude: 0.08, frequency: 100.0, seed: 31390)
        let icosa = MDLMesh.newIcosahedron(withRadius: Float(halfWidth), inwardNormals: false, allocator: nil)
        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 3)!
        let water = makeCrinkly(mdlMesh: shape, noise: noise, levels: 0, smoothing: 1, offset: 0.2, assignColours: false)
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor.blue
        waterMaterial.specular.contents = NSColor.white
        waterMaterial.shininess = 0.5
        waterMaterial.locksAmbientWithDiffuse = true
        if wireframe {
            waterMaterial.fillMode = .lines
        }
        water.materials = [waterMaterial]
        let waterNode = SCNNode(geometry: water)
        scene.rootNode.addChildNode(waterNode)
    }

    private func makeClouds() {

        let sourceNoise = GradientNoise3D(amplitude: 4.0, frequency: 0.004, seed: seed)
        let noise = FBM(sourceNoise, octaves: 2, persistence: persistence, lacunarity: lacunarity)
        let cloudWidth: Float = Float(halfWidth)// * 2.1

        var indices = [vector_int4]()

        let outerRadius = 200
        let innerRadius = outerRadius - 2
        for k in -outerRadius..<outerRadius {
            for j in -outerRadius..<outerRadius {
                for i in -outerRadius..<outerRadius {
                    let h2 = i*i + j*j + k*k
                    if h2 > innerRadius*innerRadius && h2 < outerRadius*outerRadius {
                        let rawNoise = noise.evaluate(Double(i), Double(j), Double(k))
                        if rawNoise > 1.0 {
                            let v: vector_int4 = [Int32(i+outerRadius)/2, Int32(j+outerRadius)/2, Int32(k+outerRadius)/2, 0]
                            indices.append(v)
                        }
                    }
                }
            }
        }

        let indicesBufferLength = MemoryLayout<vector_int4>.size * indices.count
        let indicesData = NSData(bytes: indices, length: indicesBufferLength) as Data

        let cloud = MDLVoxelArray(data: indicesData, boundingBox: MDLAxisAlignedBoundingBox(maxBounds: [cloudWidth, cloudWidth, cloudWidth], minBounds: [-cloudWidth, -cloudWidth, -cloudWidth]), voxelExtent: 0.001)
        let mesh = cloud.mesh(using: allocator)!
        let torus = SCNGeometry(mdlMesh: mesh)
//        let material = SCNMaterial()
//        material.diffuse.contents = NSColor.yellow
//        material.specular.contents = NSColor.white
//        material.shininess = 0.5
//        material.locksAmbientWithDiffuse = true
//        material.fillMode = .fill
//        torus.materials = [material]
        let node = SCNNode(geometry: torus)
        node.castsShadow = true
        let s = Double(width)/(Double(outerRadius)/2.0) * 1.1
        node.scale = SCNVector3(s, s, s)
        let p = -(Double(width*1.1))
        node.position = SCNVector3(p, p, p)
        scene.rootNode.addChildNode(node)
    }

    private func makeRoot() {

        let phi: Float = 1.6180339887498948482

        var positions: [float3] = [
            [1, phi, 0],
            [-1, phi, 0],
            [1, -phi, 0],
            [-1, -phi, 0],
            [0, 1, phi],
            [0, -1, phi],
            [0, 1, -phi],
            [0, -1, -phi],
            [phi, 0, 1],
            [-phi, 0, 1],
            [phi, 0, -1],
            [-phi, 0, -1]
        ]

        let faces: [[UInt32]] = [
            [4, 5, 8],
            [4, 9, 5],
            [4, 8, 0],
            [4, 1, 9],
            [0, 1, 4],
            [1, 11, 9],
            [9, 11, 3],
            [1, 6, 11],
            [0, 6, 1],
            [5, 9, 3],
            [10, 0, 8],
            [10, 6, 0],
            [11, 7, 3],
            [5, 2, 8],
            [10, 8, 2],
            [10, 2, 7],
            [6, 7, 11],
            [6, 10, 7],
            [5, 3, 2],
            [2, 3, 7],
        ]

        var faceNodes = [Quadtree?](repeating: nil, count: faces.count)
        terrainQueue.async {
            DispatchQueue.concurrentPerform(iterations: faces.count) { faceIndex in
                let face = faces[faceIndex]
                let vertices = [positions[Int(face[0])], positions[Int(face[1])], positions[Int(face[2])]]
                faceNodes[faceIndex] = self.makeFace(faceIndex: UInt32(faceIndex), corners: vertices, depth: UInt32(quadtreeDepth))
            }
        }

        self.scene.rootNode.addChildNode(terrainNode)
    }

    private func makeFace(faceIndex: UInt32, corners: [float3], depth: UInt32) -> Quadtree {
//        print(faceIndex, depth)
        //guard depth > facetree.depth else { return }

        let quadtree = Quadtree(rootFaceIndex: faceIndex, corners: corners)

        // Make patch for this level.
        let geometry = self.makePatch(positions: quadtree.corners, depth: UInt32(subdivisionsPerNode))
        let node = SCNNode(geometry: geometry)
        quadtree.node = node
        quadtree.depth = UInt32(depth)

        DispatchQueue.main.async {
            self.terrainNode.addChildNode(node)
        }

        // Subdivide quadtree.
        if depth > 0 {
            terrainQueue.async {
            let (subvertices, subindices) = self.subdivideTriangle(vertices: quadtree.corners, subdivisionLevels: 1)
                DispatchQueue.concurrentPerform(iterations: subindices.count) { i in
                let subindex = subindices[i]
                let vertices = [subvertices[Int(subindex[0])], subvertices[Int(subindex[1])], subvertices[Int(subindex[2])]]
                let subquadtree = self.makeFace(faceIndex: faceIndex, corners: vertices, depth: depth-1)
                quadtree.subtrees.append(subquadtree)
            }
                DispatchQueue.main.async {
                    node.removeFromParentNode()
                }
            }
        }

        return quadtree
    }

    private func makePatch(positions: [float3], depth: UInt32) -> SCNGeometry {
        let (subpositions, subindices) = subdivideTriangle(vertices: positions, subdivisionLevels: depth)
        let detailMesh = makeMesh(positions: subpositions, indices: Array(subindices.joined()))
        let geometry = makeCrinkly(mdlMesh: detailMesh, noise: terrainNoise, levels: levels, smoothing: smoothing, offset: 0.0, assignColours: !wireframe)
        if wireframe {
            let material = SCNMaterial()
            material.diffuse.contents = NSColor.white
            material.locksAmbientWithDiffuse = true
            material.fillMode = .lines
            geometry.materials = [material]
        }
        return geometry
    }

    private func makeMesh(positions: [float3], indices: [UInt32]) -> MDLMesh {

        let numVertices = positions.count
        let numIndices = indices.count

        let positionBufferLength: Int = MemoryLayout<float3>.size * positions.count
        let positionBuffer = allocator.newBuffer(positionBufferLength, type: .vertex)
        let positionData = NSData(bytes: positions, length: positionBufferLength) as Data
        positionBuffer.fill(positionData, offset: 0)

        let indicesBufferLength = MemoryLayout<UInt32>.size * indices.count
        let indicesBuffer = allocator.newBuffer(indicesBufferLength, type: .index)
        let indicesData = NSData(bytes: indices, length: indicesBufferLength) as Data
        indicesBuffer.fill(indicesData, offset: 0)

        let submesh = MDLSubmesh(indexBuffer: indicesBuffer, indexCount: numIndices, indexType: .uInt32, geometryType: .triangles, material: nil)

        let vertexDescriptor = MDLVertexDescriptor()
        let positionAttribute = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.addOrReplaceAttribute(positionAttribute)
        let positionLayout = MDLVertexBufferLayout(stride: MemoryLayout<float3>.size)
        vertexDescriptor.layouts = [positionLayout]

        let mesh = MDLMesh(vertexBuffers: [positionBuffer], vertexCount: numVertices, descriptor: vertexDescriptor, submeshes: [submesh])

        return mesh
    }

    private func pow(_ base: UInt32, _ power: UInt32) -> UInt32 {
        var answer: UInt32 = 1
        for _ in 0..<power { answer *= base }
        return answer
    }

    private func subdivideTriangle(vertices: [float3], subdivisionLevels: UInt32) -> ([float3], [[UInt32]]) {

        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]

        let segments = pow(2, subdivisionLevels)

        let dab = b - a
        let lab = length(dab)
        let slab = lab / Float(segments)
        let vab = dab.normalized() * slab

        let dbc = c - b
        let lbc = length(dbc)
        let slbc = lbc / Float(segments)
        let vbc = dbc.normalized() * slbc

        var next: UInt32 = 0
        var faces = [[UInt32]]()
        var points = [float3]()
        points.append(a)
        for j in 1...segments {
            let p = a + (vab * Float(j))
            points.append(p)
            for i in 1...j {
                let q = p + (vbc * Float(i))
                points.append(q)
                if i < j {
                    faces.append([next, next+j, next+j+1])
                    faces.append([next, next+j+1, next+1])
                    next += 1
                }
            }
            faces.append([next, next+j, next+j+1])
            next += 1
        }

        return (points, faces)
    }

    private func makeCrinkly(mdlMesh: MDLMesh, noise: Noise, levels: Int, smoothing: Int, offset: CGFloat, assignColours: Bool) -> SCNGeometry {

        let vertices = mdlMesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition, as: .float3)!
        let numVertices = mdlMesh.vertexCount
        let bytes = vertices.map.bytes
        let stride = vertices.stride
        let descriptorOffset = 0

        var colors = [float3]()
        for vertexNumber in 0..<numVertices {
            let index = vertexNumber * stride + descriptorOffset
            let x = Double(vertices.dataStart.load(fromByteOffset: index, as: Float.self))
            let y = Double(vertices.dataStart.load(fromByteOffset: index+4, as: Float.self))
            let z = Double(vertices.dataStart.load(fromByteOffset: index+8, as: Float.self))
            let nv = SCNVector3([x, y, z]).normalized()
            let v = nv * width
            let rawNoise = noise.evaluate(Double(v.x), Double(v.y), Double(v.z))
            let delta: CGFloat
            if levels > 0 {
                let ratio = Double(amplitude) / Double(levels)
                delta = CGFloat(ratio * round(rawNoise / ratio))
            } else {
                delta = CGFloat(rawNoise)
            }
            let dv = nv * (width + delta + offset)
            let point: float3 = [Float(dv.x), Float(dv.y), Float(dv.z)]
            bytes.storeBytes(of: point.x, toByteOffset: index, as: Float.self)
            bytes.storeBytes(of: point.y, toByteOffset: index+4, as: Float.self)
            bytes.storeBytes(of: point.z, toByteOffset: index+8, as: Float.self)
            if Float(delta) > (Float(width)-abs(point.y))/Float(iciness/width) {
                colors.append([1.0, 1.0, 1.0])
            } else {
                let colour = Double(delta) / halfAmplitude
                colors.append([0.0, Float(colour), 0.0])
            }
        }

        let colourData = NSData(bytes: colors, length: MemoryLayout<float3>.size * colors.count)
        let colourSource = SCNGeometrySource(data: colourData as Data, semantic: .color, vectorCount: colors.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: MemoryLayout<float3>.size)

        let geometry = SCNGeometry(mdlMesh: mdlMesh)
        let vertexSource = geometry.sources(for: .vertex).first!
        let indexElement = geometry.element(at: 0)
        var sources = [vertexSource]
        if assignColours {
            sources.append(colourSource)
        }
        let finalGeometry = SCNGeometry(sources: sources, elements: [indexElement])
        finalGeometry.wantsAdaptiveSubdivision = smoothing > 0 ? true : false
        finalGeometry.subdivisionLevel = smoothing
        return finalGeometry
    }
}
