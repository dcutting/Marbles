import AppKit
import QuartzCore
import SceneKit
import SceneKit.ModelIO
import ModelIO

let maxEdgeLength = 300.0
let minimumSubdivision: UInt32 = 0
let lowSubdivisions: UInt32 = 4
let highSubdivisions: UInt32 = lowSubdivisions + 1
let maxDepth = 50
let updateInterval = 0.1
let wireframe = false
let smoothing = 0

class MarbleViewController: NSViewController {

    var screenWidth: CGFloat = 0.0
    var screenHeight: CGFloat = 0.0
    let scene = SCNScene()
    let terrainNode = SCNNode()
    let terrainQueues = [DispatchQueue](repeating: DispatchQueue(label: "terrain", qos: .userInteractive, attributes: .concurrent), count: 20)
    var lowPatchCache = PatchCache<Patch>()
    var highPatchCache = PatchCache<Patch>()
    lazy var fractalNoiseConfig: FractalNoiseConfig = {
        return FractalNoiseConfig(amplitude: Double(radius / 8.0),
                                  frequency: Double(1.0 / radius),
                                  seed: 729,
                                  octaves: 15,
                                  persistence: 0.5,
                                  lacunarity: 2.0)
    }()
    lazy var lowPatchCalculator: PatchCalculator = {
        let noise = makeFractalNoise(config: fractalNoiseConfig)
        var config = PatchCalculator.Config(name: "low", priority: .high, noise: noise)
        config.radius = radius
        config.amplitude = fractalNoiseConfig.amplitude
        return PatchCalculator(config: config)
    }()
    lazy var highPatchCalculator: PatchCalculator = {
        let noise = makeFractalNoise(config: fractalNoiseConfig)
        var config = PatchCalculator.Config(name: "high", priority: .low, noise: noise)
        config.radius = radius
        config.amplitude = fractalNoiseConfig.amplitude
        return PatchCalculator(config: config)
    }()

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
        p
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

    let radius: FP = 10000

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBounds()

        scene.background.contents = NSImage(named: "tycho")!

        let light = SCNLight()
        light.type = .directional
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.look(at: SCNVector3())
//        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 100)))
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
        cameraNode.position = SCNVector3(x: 0.0, y: 0.0, z: CGFloat(radius * 2.5))
        cameraNode.camera = camera
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.showsStatistics = true
//        scnView.defaultCameraController.interactionMode = .fly
        scnView.cameraControlConfiguration.flyModeVelocity = 50
        if wireframe {
            scnView.debugOptions = SCNDebugOptions([.renderAsWireframe])
        }

        // Marker
        let box = SCNBox(width: 100.0, height: 100.0, length: 100.0, chamferRadius: 0.0)
        let boxNode = SCNNode(geometry: box)
        scene.rootNode.addChildNode(boxNode)

//        makeWater()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.makeTerrain()
        }

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers.insert(clickGesture, at: 0)
        scnView.gestureRecognizers = gestureRecognizers
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateBounds()
    }

    private func updateBounds() {
        screenWidth = view.bounds.width
        screenHeight = view.bounds.height
        print(screenWidth, screenHeight)
    }

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
    }

//    private func makeWater() {
//        let icosa = MDLMesh.newIcosahedron(withRadius: Float(radius * 1.34), inwardNormals: false, allocator: nil)
//        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 6)!
//        let water = SCNGeometry(mdlMesh: shape)
//        let waterMaterial = SCNMaterial()
//        waterMaterial.diffuse.contents = NSColor.blue
//        waterMaterial.specular.contents = NSColor.white
//        waterMaterial.shininess = 0.5
//        waterMaterial.locksAmbientWithDiffuse = true
//        water.materials = [waterMaterial]
//        let waterNode = SCNNode(geometry: water)
//        scene.rootNode.addChildNode(waterNode)
//    }

    private func makeTerrain() {
        for faceIndex in 0..<faces.count {
            let face = faces[faceIndex]
            let vertices = [positions[Int(face[0])], positions[Int(face[1])], positions[Int(face[2])]]
            lowPatchCalculator.calculate("\(faceIndex)-", vertices: vertices, subdivisions: 0) { patch in
                let geometry = makeGeometry(patch: patch, asWireframe: wireframe)
                let node = SCNNode(geometry: geometry)
                self.terrainNode.addChildNode(node)
                self.terrainQueues[faceIndex].async {
                    self.refreshGeometry(faceIndex: faceIndex, node: node)
                }
            }
        }
        self.scene.rootNode.addChildNode(terrainNode)
    }

    private func refreshGeometry(faceIndex: Int, node: SCNNode) {
        let face = self.faces[faceIndex]
        let vertices = [self.positions[Int(face[0])], self.positions[Int(face[1])], self.positions[Int(face[2])]]
        let geom = self.makeAdaptiveGeometry(faceIndex: faceIndex, corners: vertices, maxEdgeLength: maxEdgeLength)
        DispatchQueue.main.async {
            node.geometry = geom
            self.terrainQueues[faceIndex].asyncAfter(deadline: .now() + updateInterval) {
                self.refreshGeometry(faceIndex: faceIndex, node: node)
            }
        }
    }

    private func makeAdaptiveGeometry(faceIndex: Int, corners: [FP3], maxEdgeLength: FP) -> SCNGeometry {
        let patch = makeAdaptivePatch(name: "\(faceIndex)-",
            corners: corners,
            maxEdgeLengthSq: maxEdgeLength * maxEdgeLength,
            patchCache: lowPatchCache,
            depth: 0)
            ?? lowPatchCalculator.subdivideTriangle(vertices: corners,
                                                    subdivisionLevels: minimumSubdivision)
        return makeGeometry(patch: patch, asWireframe: wireframe)
    }

    private func makeAdaptivePatch(name: String, corners: [FP3], maxEdgeLengthSq: FP, patchCache: PatchCache<Patch>, depth: UInt32) -> Patch? {

        if depth >= maxDepth {
            print("hit max depth \(maxDepth)")
            return nil
        }

        let sphericalisedCorners = lowPatchCalculator.sphericalise(vertices: corners)

        let v0 = sphericalisedCorners[0]
        let v1 = sphericalisedCorners[1]
        let v2 = sphericalisedCorners[2]

        let scnView = view as! SCNView
        let p0 = scnView.projectPoint(SCNVector3(v0))
        let p1 = scnView.projectPoint(SCNVector3(v1))
        let p2 = scnView.projectPoint(SCNVector3(v2))

        var subdivide = false
        if isIntersecting(p0, p1, p2, width: screenWidth, height: screenHeight) {
            let l0 = FP((p0 - p1).lengthSq())
            let l1 = FP((p0 - p2).lengthSq())
            let l2 = FP((p1 - p2).lengthSq())
            let dumbLength: FP = 10000000000
            if (l0 > maxEdgeLengthSq || l1 > maxEdgeLengthSq || l2 > maxEdgeLengthSq) &&
                (l0 < dumbLength && l1 < dumbLength && l2 < dumbLength) {
                subdivide = true
            }
        }

        if subdivide {
            let (subv, sube) = lowPatchCalculator.sphericallySubdivide(vertices: corners)
            var subVertices = [[Patch.Vertex]](repeating: [], count: 4)
            var subColours = [[Patch.Colour]](repeating: [], count: 4)
            var subIndices = [[Patch.Index]](repeating: [], count: 4)
            var foundAllSubPatches = true
            for i in 0..<sube.count {
                let index = sube[i]
                let vx = subv[Int(index[0])]
                let vy = subv[Int(index[1])]
                let vz = subv[Int(index[2])]
                let subName = name + "\(i)"
                guard let subPatch = makeAdaptivePatch(name: subName,
                                                 corners: [vx, vy, vz],
                                                 maxEdgeLengthSq: maxEdgeLengthSq,
                                                 patchCache: patchCache,
                                                 depth: depth + 1)
                    else {
                        foundAllSubPatches = false
                        break
                }
                subVertices[i] = subPatch.vertices
                subColours[i] = subPatch.colours
                subIndices[i] = subPatch.indices
            }
            if foundAllSubPatches {
                var vertices = [Patch.Vertex]()
                var colours = [Patch.Colour]()
                var indices = [Patch.Index]()
                var offset: UInt32 = 0
                for i in 0..<4 {
                    vertices.append(contentsOf: subVertices[i])
                    colours.append(contentsOf: subColours[i])
                    let offsetEdges = subIndices[i].map { index in index + offset }
                    offset += UInt32(subVertices[i].count)
                    indices.append(contentsOf: offsetEdges)
                }
                return Patch(vertices: vertices, colours: colours, indices: indices)
            }
        }

        if let patch = highPatchCache.read(name) {
            return patch
        } else if !highPatchCalculator.isCalculating(name, subdivisions: highSubdivisions) {
            highPatchCalculator.calculate(name, vertices: corners, subdivisions: highSubdivisions) { patch in
                self.highPatchCache.write(name, patch: patch)
            }
        }

        if let patch = lowPatchCache.read(name) {
            return patch
        } else if !lowPatchCalculator.isCalculating(name, subdivisions: lowSubdivisions) {
            lowPatchCalculator.calculate(name, vertices: corners, subdivisions: lowSubdivisions) { patch in
                self.lowPatchCache.write(name, patch: patch)
            }
        }

        return nil
    }
}
