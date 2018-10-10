import AppKit
import QuartzCore
import SceneKit
import SceneKit.ModelIO
import ModelIO

class MarbleViewController: NSViewController {

    let width: CGFloat = 20.0
    lazy var halfWidth: CGFloat = width / 2.0
    let subdivision = 0

    let scene = SCNScene()
    var terrainNode: SCNNode?

    override func viewDidLoad() {
        super.viewDidLoad()

        scene.fogColor = NSColor.black
        scene.fogStartDistance = width*2.0
        scene.fogEndDistance = width*5.0

        SCNTransaction.animationDuration = 1.0

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: width * 1.1, z: 0.0)
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .directional
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.look(at: SCNVector3())
        lightNode.position = SCNVector3(x: 0, y: width, z: width)
//        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 10)))
        scene.rootNode.addChildNode(lightNode)

        let light2 = SCNLight()
        light2.type = .directional
        let lightNode2 = SCNNode()
        lightNode2.light = light2
        lightNode2.look(at: SCNVector3())
        lightNode2.position = SCNVector3(x: 0, y: -width, z: -width)
        //        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 10)))
        scene.rootNode.addChildNode(lightNode2)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.2, alpha: 1.0)
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
    }

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
        self.updateTerrain()
    }

    private func updateTerrain() {
        let noises = [
            GradientNoise3D(amplitude: 1.0, frequency: 0.4, seed: 313910),
            GradientNoise3D(amplitude: 1.0, frequency: 0.1, seed: 3139102),
            GradientNoise3D(amplitude: 0.7, frequency: 1.0, seed: 31390),
            GradientNoise3D(amplitude: 0.2, frequency: 2.0, seed: 3110),
            GradientNoise3D(amplitude: 0.05, frequency: 20.0, seed: 310),
        ]
        let land = makeIcosphere(noises: noises, detail: 7, smoothing: 1)
        let landMaterial = SCNMaterial()
        landMaterial.diffuse.contents = NSColor.green
        landMaterial.locksAmbientWithDiffuse = true
        land.materials = [landMaterial]
        terrainNode?.removeFromParentNode()
        let mesh = SCNNode(geometry: land)
        scene.rootNode.addChildNode(mesh)
        terrainNode = mesh
    }

    private func makeWater() {
        let noises = [
            GradientNoise3D(amplitude: 0.3, frequency: 5.0, seed: 31390),
        ]
        let water = makeIcosphere(noises: noises, detail: 4, smoothing: 1)
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor.blue
        waterMaterial.locksAmbientWithDiffuse = true
        water.materials = [waterMaterial]
        let waterNode = SCNNode(geometry: water)
        scene.rootNode.addChildNode(waterNode)
    }

    private func makeIcosphere(noises: [GradientNoise3D], detail: Int, smoothing: Int) -> SCNGeometry {

        let icosa = MDLMesh.newIcosahedron(withRadius: Float(halfWidth), inwardNormals: false, allocator: nil)
        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: detail)!

        let vertices = shape.vertexAttributeData(forAttributeNamed: "position", as: MDLVertexFormat.float3)!
        let numVertices = shape.vertexCount

        let bytes = vertices.map.bytes
        let stride = vertices.stride
        let descriptorOffset = 0

        for vertexNumber in 0..<numVertices {
            let index = vertexNumber * stride + descriptorOffset
            let x = Double(vertices.dataStart.load(fromByteOffset: index, as: Float.self))
            let y = Double(vertices.dataStart.load(fromByteOffset: index+4, as: Float.self))
            let z = Double(vertices.dataStart.load(fromByteOffset: index+8, as: Float.self))
            let noise = noises.reduce(0.0) { a, n in a + n.evaluate(x, y, z) }
            let delta: CGFloat = CGFloat(noise) * width/100.0
//            print(noise, delta)

            let v = SCNVector3([x, y, z])
            let deform = v.normalized() * delta
            let dv = v + deform
            let point: float3 = [Float(dv.x), Float(dv.y), Float(dv.z)]
            // convert point to bytes, then store them in the right place
            bytes.storeBytes(of: point.x, toByteOffset: index, as: Float.self)
            bytes.storeBytes(of: point.y, toByteOffset: index+4, as: Float.self)
            bytes.storeBytes(of: point.z, toByteOffset: index+8, as: Float.self)
        }
        let geometry = SCNGeometry(mdlMesh: shape)
        geometry.wantsAdaptiveSubdivision = smoothing > 0 ? true : false
        geometry.subdivisionLevel = smoothing
        return geometry
    }
}
