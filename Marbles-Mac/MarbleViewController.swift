import AppKit
import SceneKit

class MarbleViewController: NSViewController {

    let planet = earthConfig
    let maxEdgeLength = 90.0
    let detailSubdivisions: UInt32 = 4
    let adaptivePatchMaxDepth = 50
    let updateInterval = 0.5
    var wireframe: Bool = false {
        didSet {
            let scnView = view as? SCNView
            if wireframe {
                scnView?.debugOptions.insert(.renderAsWireframe)
            } else {
                scnView?.debugOptions.remove(.renderAsWireframe)
            }
        }
    }
    let hasDays = false

    var screenWidth: CGFloat = 0.0
    var screenHeight: CGFloat = 0.0
    var screenCenter = SCNVector3()
    let scene = SCNScene()
    let terrainNode = SCNNode()
    let terrainQueues = [DispatchQueue](repeating: DispatchQueue(label: "terrain", qos: .userInitiated, attributes: .concurrent), count: faces.count)
    var patchCache = PatchCache<Patch>()
    var patchCalculator: PatchCalculator!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBounds()

        patchCalculator = PatchCalculator(config: planet)

        scene.background.contents = NSImage(named: "tycho")!

        let light = SCNLight()
        light.type = .directional
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.look(at: SCNVector3())
        if hasDays {
            lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 100)))
        }
        scene.rootNode.addChildNode(lightNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.1, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true
        let cameraNode = SCNNode()
        cameraNode.position = SCNVector3(x: 0.0, y: 0.0, z: CGFloat(planet.radius * 2.5))
        cameraNode.camera = camera
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.cameraControlConfiguration.flyModeVelocity = 50

        let originMarker = SCNBox(width: 100.0, height: 100.0, length: 100.0, chamferRadius: 0.0)
        scene.rootNode.addChildNode(SCNNode(geometry: originMarker))

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
        screenCenter = SCNVector3(screenWidth/2.0, screenHeight/2.0, 0.0)
        print(screenCenter)
    }

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
        wireframe.toggle()
//        let scnView = view as! SCNView
//        let mode = scnView.defaultCameraController.interactionMode
//        scnView.defaultCameraController.interactionMode = mode == .fly ? .orbitCenteredArcball : .fly
    }

    private func makeTerrain() {
        for faceIndex in 0..<faces.count {
            let face = faces[faceIndex]
            let vertices = [positions[Int(face[0])], positions[Int(face[1])], positions[Int(face[2])]]
            let patch = patchCalculator.subdivideTriangle(vertices: vertices, subdivisionLevels: 0)
            let geometry = makeGeometry(patch: patch, asWireframe: self.wireframe)
            let node = SCNNode(geometry: geometry)
            self.terrainNode.addChildNode(node)
            self.terrainQueues[faceIndex].async {
                self.refreshGeometry(faceIndex: faceIndex, node: node)
            }
        }
        self.scene.rootNode.addChildNode(terrainNode)
    }

    private func refreshGeometry(faceIndex: Int, node: SCNNode) {
        patchCalculator.clearBuffer()
        let scnView = view as! SCNView
        let distance = scnView.defaultCameraController.pointOfView!.position.length()
        let newVelocity = ((FP(distance) - planet.radius) / planet.radius) * planet.radius / 10.0
        scnView.cameraControlConfiguration.flyModeVelocity = CGFloat(newVelocity)
        let face = faces[faceIndex]
        let vertices = [positions[Int(face[0])], positions[Int(face[1])], positions[Int(face[2])]]
        let geom = self.makeAdaptiveGeometry(faceIndex: faceIndex, corners: vertices, maxEdgeLength: maxEdgeLength)
        DispatchQueue.main.async {
            node.geometry = geom
            self.terrainQueues[faceIndex].asyncAfter(deadline: .now() + self.updateInterval) {
                self.refreshGeometry(faceIndex: faceIndex, node: node)
            }
        }
    }

    private func makeAdaptiveGeometry(faceIndex: Int, corners: [FP3], maxEdgeLength: FP) -> SCNGeometry {
        let patch = makeAdaptivePatch(name: "\(faceIndex)-",
            corners: corners,
            maxEdgeLengthSq: maxEdgeLength * maxEdgeLength,
            patchCache: patchCache,
            depth: 0)
            ?? patchCalculator.subdivideTriangle(vertices: corners,
                                                    subdivisionLevels: detailSubdivisions)
        return makeGeometry(patch: patch, asWireframe: wireframe)
    }

    private func makeAdaptivePatch(name: String, corners: [FP3], maxEdgeLengthSq: FP, patchCache: PatchCache<Patch>, depth: UInt32) -> Patch? {

        if depth >= adaptivePatchMaxDepth {
            print("hit max depth \(adaptivePatchMaxDepth)")
            return nil
        }

        let scnView = view as! SCNView
        let cameraPosition = scnView.defaultCameraController.pointOfView!.position
        let distanceSq = cameraPosition.lengthSq()
        let aD = (SCNVector3(corners[0]) - cameraPosition).lengthSq()
        let bD = (SCNVector3(corners[1]) - cameraPosition).lengthSq()
        let cD = (SCNVector3(corners[2]) - cameraPosition).lengthSq()
        let minimumTriangleDistance = min(aD, bD, cD)
        guard minimumTriangleDistance < distanceSq else { return nil }
        // TODO doesn't work great for low angle vistas

        let sphericalisedCorners = patchCalculator.sphericalise(vertices: corners)

        let v0 = sphericalisedCorners[0]
        let v1 = sphericalisedCorners[1]
        let v2 = sphericalisedCorners[2]

        let p0 = scnView.projectPoint(SCNVector3(v0))
        let p1 = scnView.projectPoint(SCNVector3(v1))
        let p2 = scnView.projectPoint(SCNVector3(v2))

        let p0d = (p0 - screenCenter).lengthSq()
        let p1d = (p1 - screenCenter).lengthSq()
        let p2d = (p2 - screenCenter).lengthSq()
        let pm = min(p0d, p1d, p2d)
        if pm < 100 {
            print(pm)
        }

        var subdivide = false
        if isIntersecting(p0, p1, p2, width: screenWidth, height: screenHeight) {
            let l0 = FP((p0 - p1).lengthSq())
            let l1 = FP((p0 - p2).lengthSq())
            let l2 = FP((p1 - p2).lengthSq())
            let dumbLength: FP = 100000000000000
            if l0 > maxEdgeLengthSq || l1 > maxEdgeLengthSq || l2 > maxEdgeLengthSq {
                if l0 < dumbLength && l1 < dumbLength && l2 < dumbLength {
                    subdivide = true
                } else {
//                    print("dumb:", name, l0, l1, l2)
                }
            }
        }

        if subdivide {
            let (subv, sube) = patchCalculator.sphericallySubdivide(vertices: corners)
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

        if let stitchedPatch = stitchSubPatches(name: name) {
            return stitchedPatch
        } else {
            let (subv, sube) = patchCalculator.sphericallySubdivide(vertices: corners)
            for i in 0..<sube.count {
                let index = sube[i]
                let vx = subv[Int(index[0])]
                let vy = subv[Int(index[1])]
                let vz = subv[Int(index[2])]
                let subName = name + "\(i)"
                // TODO pm?
                let priority = Double(pow(minimumTriangleDistance, 10))
                patchCalculator.calculate(subName, vertices: [vx, vy, vz], subdivisions: detailSubdivisions, priority: priority) { patch in
                    self.patchCache.write(subName, patch: patch)
                }
            }
            if let cachedPatch = patchCache.read(name) {
                return cachedPatch
            } else {
                // TODO: pm?
                patchCalculator.calculate(name, vertices: corners, subdivisions: detailSubdivisions, priority: Double(minimumTriangleDistance)) { patch in
                    self.patchCache.write(name, patch: patch)
                }
                return nil
            }
        }
    }

    private func stitchSubPatches(name: String) -> Patch? {
        for depth: UInt32 in (1..<2).reversed() {
            let subPatches = findSubPatches(name: name, depth: depth)
            if pow(4, depth) == subPatches.count {
                var vertices = [Patch.Vertex]()
                var colours = [Patch.Colour]()
                var indices = [Patch.Index]()
                var offset: UInt32 = 0
                for subPatch in subPatches {
                    vertices.append(contentsOf: subPatch.vertices)
                    colours.append(contentsOf: subPatch.colours)
                    let offsetEdges = subPatch.indices.map { index in index + offset }
                    offset += UInt32(subPatch.vertices.count)
                    indices.append(contentsOf: offsetEdges)
                }
                return Patch(vertices: vertices, colours: colours, indices: indices)
            }
        }
        return nil
    }

    private func findSubPatches(name: String, depth: UInt32) -> [Patch] {
        if depth == 0 {
            if let patch = patchCache.read(name) {
                return [patch]
            } else {
                return []
            }
        }
        var subPatches = [Patch]()
        for subName in [name+"0", name+"1", name+"2", name+"3"] {
            subPatches.append(contentsOf: findSubPatches(name: subName, depth: depth - 1))
        }
        return subPatches
    }
}
