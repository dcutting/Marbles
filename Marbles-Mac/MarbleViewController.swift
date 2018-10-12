import AppKit
import QuartzCore
import SceneKit
import SceneKit.ModelIO
import ModelIO
import MetalKit

class MarbleViewController: NSViewController {

    let width: CGFloat = 20.0
    lazy var halfWidth: CGFloat = width / 2.0
    let subdivision = 0

    let scene = SCNScene()
    var terrainNode: SCNNode?

    let terrainNoises = [
        GradientNoise3D(amplitude: 4.0, frequency: 0.125, seed: 310567),
        GradientNoise3D(amplitude: 2.0, frequency: 0.25, seed: 313902),
        GradientNoise3D(amplitude: 1.0, frequency: 0.5, seed: 313910),
        GradientNoise3D(amplitude: 0.5, frequency: 1.0, seed: 31390),
        GradientNoise3D(amplitude: 0.25, frequency: 2.0, seed: 3110),
        GradientNoise3D(amplitude: 0.125, frequency: 4.0, seed: 310),
        GradientNoise3D(amplitude: 0.0625, frequency: 8.0, seed: 310321),
        GradientNoise3D(amplitude: 0.03125, frequency: 16.0, seed: 310321),
        GradientNoise3D(amplitude: 0.015625, frequency: 32.0, seed: 310321),
        GradientNoise3D(amplitude: 0.0078125, frequency: 64.0, seed: 310321),
        GradientNoise3D(amplitude: 0.00390625, frequency: 128.0, seed: 310321),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        scene.fogColor = NSColor.black
        scene.fogStartDistance = width*2.0
        scene.fogEndDistance = width*10.0
        scene.background.contents = NSImage(named: "tycho")!

        SCNTransaction.animationDuration = 1.0

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: width * 1.1, z: 0.0)
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .directional
//        light.color = NSColor.darkGray
//        light.intensity = 10000
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.look(at: SCNVector3())
        lightNode.position = SCNVector3(x: 0, y: 10*width, z: 10*width)
//        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 10)))
        scene.rootNode.addChildNode(lightNode)

        let light2 = SCNLight()
        light2.type = .directional
        let lightNode2 = SCNNode()
        lightNode2.light = light2
        lightNode2.look(at: SCNVector3())
        lightNode2.position = SCNVector3(x: 0, y: -10*width, z: -10*width)
        //        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 10)))
        scene.rootNode.addChildNode(lightNode2)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.5, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        scnView.backgroundColor = NSColor.black

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers.insert(clickGesture, at: 0)
        scnView.gestureRecognizers = gestureRecognizers

        makeWater()
        updateTerrain()
//        makeDetailedTerrain()
        makePatch()
    }

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
        self.updateTerrain()
    }

    private func updateTerrain() {
        let icosa = MDLMesh.newIcosahedron(withRadius: Float(halfWidth), inwardNormals: false, allocator: nil)
        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 5)!
        let land = makeCrinkly(mdlMesh: shape, noises: terrainNoises, levels: 0, smoothing: 0, offset: 0.0, assignColours: true)
        terrainNode?.removeFromParentNode()
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.green
        material.specular.contents = NSColor.white
        material.shininess = 0.5
        material.locksAmbientWithDiffuse = true
//        material.fillMode = .lines
//        land.materials = [material]
        let mesh = SCNNode(geometry: land)
        scene.rootNode.addChildNode(mesh)
        terrainNode = mesh
    }

    private func makePatch() {

        let h = Float(width/4)
        let o: Float = Float(halfWidth)

        let positions: [float3] = [
            [0.000000, h+o, -h],
            [-0.866*h, h+o, 0.5*h],
            [0.866*h, h+o, 0.5*h],
        ]

        let numVertices = 3

        let positionBufferLength: Int = MemoryLayout<float3>.size * positions.count

        let allocator = MDLMeshBufferDataAllocator()
        let positionBuffer = allocator.newBuffer(positionBufferLength, type: .vertex)

        let positionData = NSData(bytes: positions, length: positionBufferLength) as Data

        positionBuffer.fill(positionData, offset: 0)

        let meshBuffers = [positionBuffer]

        let indices: [UInt16] = [ 0, 1, 2 ]

        let numIndices = indices.count

        let indicesBufferLength = MemoryLayout<UInt16>.size * indices.count

        let indicesBuffer = allocator.newBuffer(indicesBufferLength, type: .index)

        let indicesData = NSData(bytes: indices, length: indicesBufferLength) as Data

        indicesBuffer.fill(indicesData, offset: 0)

        let submesh = MDLSubmesh(indexBuffer: indicesBuffer, indexCount: numIndices, indexType: .uInt16, geometryType: .triangles, material: nil)
        let submeshes = [submesh]

        let vertexDescriptor = MDLVertexDescriptor()
        let positionAttribute = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.addOrReplaceAttribute(positionAttribute)
        let positionLayout = MDLVertexBufferLayout(stride: MemoryLayout<float3>.size)
        vertexDescriptor.layouts = [positionLayout]

        let mesh = MDLMesh(vertexBuffers: meshBuffers, vertexCount: numVertices, descriptor: vertexDescriptor, submeshes: submeshes)

        // subdivide mesh
        let detailMesh = MDLMesh.newSubdividedMesh(mesh, submeshIndex: 0, subdivisionLevels: 10)!

        // crinkle mesh
        let geometry = makeCrinkly(mdlMesh: detailMesh, noises: terrainNoises, levels: 0, smoothing: 0, offset: 0.0, assignColours: true)

        // convert mesh to geometry
//        let geometry = SCNGeometry(mdlMesh: detailMesh)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.red
        material.specular.contents = NSColor.white
        material.shininess = 0.5
        material.locksAmbientWithDiffuse = true
//        material.fillMode = .lines
//        geometry.materials = [material]

        // add geometry to scene
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)
    }

    private func makeDetailedTerrain() {
        let icosa = MDLMesh.newIcosahedron(withRadius: Float(halfWidth), inwardNormals: false, allocator: nil)
        let subicosa = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 2)!

        let vertices = subicosa.vertexAttributeData(forAttributeNamed: "position", as: MDLVertexFormat.float3)!
        let numVertices = subicosa.vertexCount
        let bytes = vertices.map.bytes
        let stride = vertices.stride
        let descriptorOffset = 0
        var rawVertices = [SCNVector3]()
        var filteredVertices = [SCNVector3]()
        for vertexNumber in 0..<numVertices {
            let index = vertexNumber * stride + descriptorOffset
            let x = Double(vertices.dataStart.load(fromByteOffset: index, as: Float.self))
            let y = Double(vertices.dataStart.load(fromByteOffset: index+4, as: Float.self))
            let z = Double(vertices.dataStart.load(fromByteOffset: index+8, as: Float.self))
            if x >= 0 && y >= 0 && z >= 0 {
                filteredVertices.append(SCNVector3(x, y, z))
            } else {
                filteredVertices.append(SCNVector3(0, 0, 0))
            }
            rawVertices.append(SCNVector3(x, y, z))
        }
        let submesh: MDLSubmesh = subicosa.submeshes!.firstObject as! MDLSubmesh
//        print(rawVertices)
//        print(filteredVertices)
//        print(submesh.geometryType.rawValue)

        let vertexData = NSData(bytes: vertices.map.bytes, length: MemoryLayout<float3>.size * rawVertices.count) as Data
        let meshBuffer = MDLMeshBufferDataAllocator().newBuffer(with: vertexData, type: .vertex)

        let patch = MDLMesh(vertexBuffers: [meshBuffer], vertexCount: rawVertices.count, descriptor: subicosa.vertexDescriptor, submeshes: subicosa.submeshes as! [MDLSubmesh])
        let land = SCNGeometry(mdlMesh: patch)

//        let shape = MDLMesh.newSubdividedMesh(patch, submeshIndex: 0, subdivisionLevels: 3)!
//        let land = makeCrinkly(mdlMesh: shape, noises: terrainNoises, levels: 0, smoothing: 0, offset: 0.0, assignColours: false)
//        let material = SCNMaterial()
//        material.diffuse.contents = NSColor.green
//        material.specular.contents = NSColor.white
//        material.shininess = 0.5
//        material.locksAmbientWithDiffuse = true
//        land.materials = [material]
        let landNode = SCNNode(geometry: land)
        scene.rootNode.addChildNode(landNode)
    }

    private func makeWater() {
        let noises = [
            GradientNoise3D(amplitude: 0.03, frequency: 50.0, seed: 31390),
        ]
        let icosa = MDLMesh.newIcosahedron(withRadius: Float(halfWidth), inwardNormals: false, allocator: nil)
        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 4)!
        let water = makeCrinkly(mdlMesh: shape, noises: noises, levels: 0, smoothing: 0, offset: 0.01, assignColours: false)
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor.blue
        waterMaterial.specular.contents = NSColor.white
        waterMaterial.shininess = 0.5
        waterMaterial.locksAmbientWithDiffuse = true
        water.materials = [waterMaterial]
        let waterNode = SCNNode(geometry: water)
        scene.rootNode.addChildNode(waterNode)
    }

    private func makeCrinkly(mdlMesh: MDLMesh, noises: [GradientNoise3D], levels: Int, smoothing: Int, offset: CGFloat, assignColours: Bool) -> SCNGeometry {

        let vertices = mdlMesh.vertexAttributeData(forAttributeNamed: "position", as: MDLVertexFormat.float3)!
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
            let noise = noises.reduce(0.0) { a, n in a + n.evaluate(Double(v.x), Double(v.y), Double(v.z)) }
            let delta: CGFloat
            if levels > 0 {
                let adjusted = CGFloat(Int(noise * Double(levels)))
                delta = adjusted * width / (100.0 * CGFloat(levels))
            } else {
                delta = CGFloat(noise * Double(width/100.0))
            }
            let dv = nv * (width + delta + offset)
            //            print(v, dv)
//            let dv = v + deform
            let point: float3 = [Float(dv.x), Float(dv.y), Float(dv.z)]
            bytes.storeBytes(of: point.x, toByteOffset: index, as: Float.self)
            bytes.storeBytes(of: point.y, toByteOffset: index+4, as: Float.self)
            bytes.storeBytes(of: point.z, toByteOffset: index+8, as: Float.self)
            if delta > 0.5 {
                colors.append([1.0, 1.0, 1.0])
            } else {
                colors.append([0.0, 9.0*Float(delta)/10.0, 0.0])
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
