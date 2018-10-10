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

        let water = SCNSphere(radius: halfWidth-2.5)
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor.blue
        waterMaterial.locksAmbientWithDiffuse = true
        water.materials = [waterMaterial]
        let waterNode = SCNNode(geometry: water)
        scene.rootNode.addChildNode(waterNode)

        updateTerrain()

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        scnView.backgroundColor = NSColor.black

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers.insert(clickGesture, at: 0)
        scnView.gestureRecognizers = gestureRecognizers
    }

    private func updateTerrain() {

        let icosa = MDLMesh.newIcosahedron(withRadius: Float(halfWidth), inwardNormals: false, allocator: nil)
        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 6)!

        let vertices = shape.vertexAttributeData(forAttributeNamed: "position", as: MDLVertexFormat.float3)!
        let numVertices = shape.vertexCount

        let bytes = vertices.map.bytes
        let stride = vertices.stride
        let descriptorOffset = 0

//        let perlin = PerlinMesh(n: Int(width), seed: 138103)

        let noise1 = GradientNoise3D(amplitude: 3.0, frequency: 0.4, seed: 313910)
        let noise2 = GradientNoise3D(amplitude: 1.0, frequency: 1.0, seed: 31390)
        let noise3 = GradientNoise3D(amplitude: 0.5, frequency: 2.0, seed: 3110)
        let noise4 = GradientNoise3D(amplitude: 0.05, frequency: 20.0, seed: 310)

        for vertexNumber in 0..<numVertices {
            let index = vertexNumber * stride + descriptorOffset
            let x = vertices.dataStart.load(fromByteOffset: index, as: Float.self)
            let y = vertices.dataStart.load(fromByteOffset: index+4, as: Float.self)
            let z = vertices.dataStart.load(fromByteOffset: index+8, as: Float.self)
            let noise = noise1.evaluate(Double(x), Double(y), Double(z))
                + noise2.evaluate(Double(x), Double(y), Double(z))
                + noise3.evaluate(Double(x), Double(y), Double(z))
                + noise4.evaluate(Double(x), Double(y), Double(z))

            let delta: CGFloat = CGFloat(noise) * width/100.0

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

        let landMaterial = SCNMaterial()
        landMaterial.diffuse.contents = NSColor.green
        landMaterial.locksAmbientWithDiffuse = true
        geometry.materials = [landMaterial]
        geometry.wantsAdaptiveSubdivision = subdivision > 0 ? true : false
        geometry.subdivisionLevel = subdivision
        terrainNode?.removeFromParentNode()
        let mesh = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(mesh)
        terrainNode = mesh
    }

    @objc
    func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
        self.updateTerrain()
    }
}
