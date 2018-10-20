import AppKit
import QuartzCore
import SceneKit
import SceneKit.ModelIO
import ModelIO

let seed = 31596
let octaves = 20
let frequency: Double = Double(1.0 / diameter)
let persistence = 0.5
let lacunarity = 2.0
let amplitude: Double = Double(radius / 4.0)
let levels = 0
let iciness: CGFloat = 150.0

let wireframe = false
let smoothing = 0
let diameter: CGFloat = 1000.0
let radius: CGFloat = diameter / 2.0
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

    var w: CGFloat!
    var h: CGFloat!

    override func viewDidLayout() {
        super.viewDidLayout()
        let scnView = self.view as! SCNView
        w = scnView.bounds.width
        h = scnView.bounds.height
        print(w,h)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scene.background.contents = NSImage(named: "tycho")!

        let light = SCNLight()
        light.type = .directional
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.look(at: SCNVector3())
        lightNode.position = SCNVector3(x: 0, y: 10*diameter, z: 10*diameter)
//        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 20)))
        scene.rootNode.addChildNode(lightNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.3, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true
        let cameraNode = SCNNode()
        cameraNode.position = SCNVector3(x: 0.0, y: 0.0, z: diameter * 1.2)
        cameraNode.camera = camera
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.showsStatistics = true
//        scnView.defaultCameraController.interactionMode = .fly
        scnView.cameraControlConfiguration.flyModeVelocity = 0.1
        if wireframe {
            scnView.debugOptions = SCNDebugOptions([.renderAsWireframe])
        }
        w = scnView.bounds.width
        h = scnView.bounds.height
        print(w,h)

        // Marker
        let box = SCNBox(width: 100.0, height: 100.0, length: 100.0, chamferRadius: 0.0)
        let boxNode = SCNNode(geometry: box)
        boxNode.position = SCNVector3(radius, 0.0, 0.0)
        scene.rootNode.addChildNode(boxNode)

//        makeWater()
//        makeClouds()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            self.makeTerrain()
//        }
//        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
//            self.updateLevelOfDetail()
//        }

        makeTerrain()

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers.insert(clickGesture, at: 0)
//        scnView.gestureRecognizers = gestureRecognizers
    }

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
    }

    private func makeWater() {
        let noise = GradientNoise3D(amplitude: 0.08, frequency: 100.0, seed: 31390)
        let icosa = MDLMesh.newIcosahedron(withRadius: Float(radius), inwardNormals: false, allocator: nil)
        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 3)!
        let water = makeCrinkly(mdlMesh: shape, noise: noise, levels: 0, smoothing: 1, offset: 0.2, assignColours: false)
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor.blue
        waterMaterial.specular.contents = NSColor.white
        waterMaterial.shininess = 0.5
        waterMaterial.locksAmbientWithDiffuse = true
        water.materials = [waterMaterial]
        let waterNode = SCNNode(geometry: water)
        scene.rootNode.addChildNode(waterNode)
    }

    private func makeClouds() {

        let sourceNoise = GradientNoise3D(amplitude: 4.0, frequency: 0.004, seed: seed)
        let noise = FBM(sourceNoise, octaves: 2, persistence: persistence, lacunarity: lacunarity)
        let cloudWidth: Float = Float(radius)// * 2.1

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
        let node = SCNNode(geometry: torus)
        node.castsShadow = true
        let s = Double(diameter)/(Double(outerRadius)/2.0) * 1.1
        node.scale = SCNVector3(s, s, s)
        let p = -(Double(diameter*1.1))
        node.position = SCNVector3(p, p, p)
        scene.rootNode.addChildNode(node)
    }

    var faceIndex = 0

    let phi: FP = 1.6180339887498948482

    lazy var platonicPositions: [FP3] = [
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

    lazy var positions: [FP3] = platonicPositions.map { p in
        p * FP(radius)
    }

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
        [2, 3, 7]
    ]

    private func makeTerrain() {
        for faceIndex in 0..<faces.count {
            let face = faces[faceIndex]
            let vertices = [positions[Int(face[0])], positions[Int(face[1])], positions[Int(face[2])]]
            let geom = makePatch(positions: vertices, indices: [0, 1, 2])
            let node = SCNNode(geometry: geom)
            self.terrainNode.addChildNode(node)
            updateRoot(faceIndex: faceIndex, node: node)
        }
        self.scene.rootNode.addChildNode(terrainNode)
    }

    var counter = 0

    private func updateRoot(faceIndex: Int, node: SCNNode) {
        self.terrainQueue.async {
            let face = self.faces[faceIndex]
            let vertices = [self.positions[Int(face[0])], self.positions[Int(face[1])], self.positions[Int(face[2])]]
            let geom = self.makeGeometry(corners: vertices, maxEdgeLength: 50.0)
            DispatchQueue.main.async {
                print("[\(faceIndex)] updated geometry: \(self.counter)")
                self.counter += 1
                node.geometry = geom
                self.updateRoot(faceIndex: faceIndex, node: node)
            }
        }
    }

    private func makeGeometry(corners: [FP3], maxEdgeLength: FP) -> SCNGeometry {
        let (vertices, edges) = makeGeometrySources(corners: corners, maxEdgeLength: maxEdgeLength, depth: 0)
        return makePatch(positions: vertices, indices: Array(edges.joined()))
    }

    let subdividedTriangleEdges: [[UInt32]] = [[0, 3, 5], [3, 1, 4], [3, 4, 5], [5, 4, 2]]

    private func makeGeometrySources(corners: [FP3], maxEdgeLength: FP, depth: UInt32) -> ([FP3], [[UInt32]]) {
        // make vertices and edges from initial corners such that no projected edge is longer
        // than maxEdgeLength
        var positions = [FP3]()
        var edges = [[UInt32]]()
        let subv = sphericallySubdivide(vertices: corners, radius: FP(radius))
        var offset: UInt32 = 0
        var subdivide = false
        let scnView = view as! SCNView

        for index in subdividedTriangleEdges {
            let vx = subv[Int(index[0])]
            let vy = subv[Int(index[1])]
            let vz = subv[Int(index[2])]
            let px = scnView.projectPoint(SCNVector3(vx))
            let py = scnView.projectPoint(SCNVector3(vy))
            let pz = scnView.projectPoint(SCNVector3(vz))

            guard intersectsScreen(px, py, pz) else { continue }

            let lx = FP((px - py).length())
            let ly = FP((px - pz).length())
            let lz = FP((py - pz).length())
//            print()
//            print(vx, vy, vz)
//            print(px, py, pz)
//            print(lx, ly, lz)
            if (lx > maxEdgeLength || ly > maxEdgeLength || lz > maxEdgeLength) {
                subdivide = true
                break
            }
        }
        if subdivide && depth < 10 {
            var newpositions = [[FP3]](repeating: [], count: 4)
            var newindices = [[[UInt32]]](repeating: [], count: 4)
            DispatchQueue.concurrentPerform(iterations: subdividedTriangleEdges.count) { i in
//            for index in subindices {
                let index = subdividedTriangleEdges[i]
                let vx = subv[Int(index[0])]
                let vy = subv[Int(index[1])]
                let vz = subv[Int(index[2])]
                let (iv, ii) = makeGeometrySources(corners: [vx, vy, vz], maxEdgeLength: maxEdgeLength, depth: depth+1)
                newpositions[i] = iv
                newindices[i] = ii
            }
            for i in 0..<4 {
                positions.append(contentsOf: newpositions[i])
                let offsetEdges = newindices[i].map { edges in
                    edges.map { edge in edge + offset }
                }
                offset += UInt32(newpositions[i].count)
                edges.append(contentsOf: offsetEdges)
            }
        } else {
            positions.append(contentsOf: subv)
            edges.append(contentsOf: subdividedTriangleEdges)
        }
        return (positions, edges)
    }

    private func intersectsScreen(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) -> Bool {
        let minX = min(a.x, b.x, c.x)
        let maxX = max(a.x, b.x, c.x)
        let minY = min(a.y, b.y, c.y)
        let maxY = max(a.y, b.y, c.y)
        let inset: CGFloat = 0.0//h / 4.0
        let overlapsX = minX <= (w + inset) && maxX >= (0 - inset)
        let overlapsY = minY <= (h + inset) && maxY >= (0 - inset)
        return overlapsX && overlapsY
    }

    private func makePatch(positions: [FP3], indices: [UInt32]) -> SCNGeometry {
        let detailMesh = makeGeometry(positions: positions, indices: indices)
        let mdlMesh = MDLMesh(scnGeometry: detailMesh)
        return makeCrinkly(mdlMesh: mdlMesh, noise: terrainNoise, levels: levels, smoothing: smoothing, offset: 0.0, assignColours: !wireframe)
    }

//    private func makePatch(positions: [FP3], depth: UInt32) -> SCNGeometry {
//        let (subpositions, subindices) = subdivideTriangle(vertices: positions, subdivisionLevels: depth)
//        let detailMesh = makeMDLMesh(positions: subpositions, indices: Array(subindices.joined()))
//        let geometry = makeCrinkly(mdlMesh: detailMesh, noise: terrainNoise, levels: levels, smoothing: smoothing, offset: 0.0, assignColours: !wireframe)
//        return geometry
//    }

    var buffer: MTLBuffer?

    private func makeGeometry(positions: [FP3], indices: [UInt32]) -> SCNGeometry {
        let vertices = positions.map { p in SCNVector3(p[0], p[1], p[2]) }
        let positionSource = SCNGeometrySource(vertices: vertices)
        let edgeElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [positionSource], elements: [edgeElement])
        return geometry
    }

    private func makeMDLMesh(positions: [float3], indices: [UInt32]) -> MDLMesh {

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

    private func sphericallySubdivide(vertices: [FP3], radius: FP) -> [FP3] {

        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]

        let ab = midway(a, b)
        let bc = midway(b, c)
        let ca = midway(c, a)

        let abs = spherical(ab, radius)
        let bcs = spherical(bc, radius)
        let cas = spherical(ca, radius)

        return [a, b, c, abs, bcs, cas]
    }

    private func midway(_ a: FP3, _ b: FP3) -> FP3 {

        let abx = (a.x + b.x) / 2.0
        let aby = (a.y + b.y) / 2.0
        let abz = (a.z + b.z) / 2.0

        return [abx, aby, abz]
    }

    private func spherical(_ a: FP3, _ radius: FP) -> FP3 {
        return a.normalized() * radius
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
            let rv = SCNVector3([x, y, z])
            let nv = rv.normalized()
            let v = nv * radius
            let rawNoise = noise.evaluate(Double(v.x), Double(v.y), Double(v.z))
            let delta: CGFloat
            if levels > 0 {
                let ratio = Double(amplitude) / Double(levels)
                delta = CGFloat(ratio * round(rawNoise / ratio))
            } else {
                delta = CGFloat(rawNoise)
            }
            let dv = nv * (radius + delta + offset)
            let point: float3 = [Float(dv.x), Float(dv.y), Float(dv.z)]
            bytes.storeBytes(of: point.x, toByteOffset: index, as: Float.self)
            bytes.storeBytes(of: point.y, toByteOffset: index+4, as: Float.self)
            bytes.storeBytes(of: point.z, toByteOffset: index+8, as: Float.self)
            if Float(delta) > (Float(diameter)-abs(point.y))/Float(iciness/diameter) {
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
