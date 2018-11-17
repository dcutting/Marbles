import AppKit
import SceneKit

let debug = false

class MarbleViewController: NSViewController {

    let planet = earthConfig
    let detailSubdivisions: UInt32 = 5
    lazy var maxEdgeLength: FP = 160.0
    let adaptivePatchMaxDepth: UInt32 = 20
    let updateInterval = 0.1
    let dayDuration: FP = 1000
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

    var screenWidth: FP = 0.0
    var halfScreenWidthSq: FP = 0.0
    var screenHeight: FP = 0.0
    var screenCenter = Patch.Vertex()
    let scene = SCNScene()
    let terrainNode = SCNNode()
    let terrainQueue = DispatchQueue(label: "terrain", qos: .userInteractive, attributes: .concurrent)
    var patchCache = PatchCache<Patch>()
    var patchCalculator: PatchCalculator!

    var scnView: SCNView {
        return view as! SCNView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBounds()

        patchCalculator = PatchCalculator(config: planet)

        scene.background.contents = NSImage(named: "tycho")!

        let light = SCNLight()
        light.type = .omni
        let sunGeometry = SCNSphere(radius: 40000)
        sunGeometry.segmentCount = 64
        let sunMaterial = SCNMaterial()
        sunMaterial.emission.contents = NSImage(named: "2k_sun")!
        sunGeometry.materials = [sunMaterial]
        let sun = SCNNode(geometry: sunGeometry)
        let bloom = CIFilter(name: "CIBloom")!
        bloom.setValue(40.0, forKey: kCIInputRadiusKey)
        bloom.setValue(1.0, forKey: kCIInputIntensityKey)
        sun.filters = [bloom]
        sun.position = SCNVector3(x: 1000000, y: 0, z: 0)
        sun.light = light
        let sunParent = SCNNode()
        sunParent.addChildNode(sun)
        sunParent.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: dayDuration)))
        scene.rootNode.addChildNode(sunParent)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.1, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true
        let cameraNode = SCNNode()
        cameraNode.position = SCNVector3(x: 0.0, y: 0.0, z: CGFloat(planet.radius * 2.2))
        cameraNode.camera = camera
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.showsStatistics = true

        let originMarker = SCNBox(width: 100.0, height: 100.0, length: 100.0, chamferRadius: 0.0)
        scene.rootNode.addChildNode(SCNNode(geometry: originMarker))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.makeTerrain()
        }

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers.insert(clickGesture, at: 0)
        gestureRecognizers.insert(doubleClickGesture, at: 1)
        scnView.gestureRecognizers = gestureRecognizers
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateBounds()
    }

    private func updateBounds() {
        screenWidth = FP(view.bounds.width)
        screenHeight = FP(view.bounds.height)
        halfScreenWidthSq = (screenWidth / 2.0) * (screenWidth / 2.0)
        screenCenter = Patch.Vertex(screenWidth / 2.0, screenHeight / 2.0, 0.0)
    }

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
        let scnView = view as! SCNView
        let mode = scnView.defaultCameraController.interactionMode
        scnView.defaultCameraController.interactionMode = mode == .fly ? .orbitCenteredArcball : .fly
    }

    @objc func handleDoubleClick(_ gestureRecognizer: NSGestureRecognizer) {
        wireframe.toggle()
    }

    var cameraPosition: Patch.Vertex {
        return Patch.Vertex(self.scnView.defaultCameraController.pointOfView!.position)
    }

    var altitude: FP {
        return (cameraPosition - Patch.Vertex(terrainNode.position)).length()
    }

    private func adaptFlyingSpeed() {
        var radius = self.planet.radius
        if !self.planet.hasWater {
            radius -= self.planet.mountainHeight
        }
        let zeroHeight = radius * 1.0
        let newVelocity = ((altitude - zeroHeight) / zeroHeight) * zeroHeight / 4.0
        self.scnView.cameraControlConfiguration.flyModeVelocity = CGFloat(newVelocity)
    }

    var nodes = [SCNNode]()
    var geometries = [SCNGeometry]()

    private func makeTerrain() {
        for faceIndex in 0..<faces.count {
            let face = faces[faceIndex]
            let triangle = Triangle(a: positions[Int(face[0])], b: positions[Int(face[1])], c: positions[Int(face[2])])
            let patch = patchCalculator.subdivide(triangle: triangle, subdivisionLevels: detailSubdivisions)
            patchCache.write("\(faceIndex)-", patch: patch)
            let geometry = makeGeometry(patch: patch, asWireframe: self.wireframe)
            let node = SCNNode(geometry: geometry)
            geometries.append(geometry)
            nodes.append(node)
            self.terrainNode.addChildNode(node)
        }
        terrainNode.position = SCNVector3(x: -10000.0, y: 0.0, z: 0.0)
        self.scene.rootNode.addChildNode(terrainNode)
        self.refreshGeometry()
    }

    private func refreshGeometry() {
        self.terrainQueue.asyncAfter(deadline: .now() + self.updateInterval) {
            self.patchCalculator.clearBuffer()
            for faceIndex in 0..<faces.count {
                let face = faces[faceIndex]
                let triangle = Triangle(a: positions[Int(face[0])], b: positions[Int(face[1])], c: positions[Int(face[2])])
                let geom = self.makeAdaptiveGeometry(faceIndex: faceIndex, corners: triangle, maxEdgeLength: self.maxEdgeLength)
                self.geometries[faceIndex] = geom
            }
            DispatchQueue.main.sync {
                if debug {
                    print("* Refreshing geometry at altitude \(self.altitude)")
                }
                for faceIndex in 0..<self.nodes.count {
                    self.nodes[faceIndex].geometry = self.geometries[faceIndex]
                }
                self.adaptFlyingSpeed()
                self.refreshGeometry()
            }
        }
    }

    private func makeAdaptiveGeometry(faceIndex: Int, corners: Triangle, maxEdgeLength: FP) -> SCNGeometry {
        let start = DispatchTime.now()
        let patch = makeAdaptivePatch(name: "\(faceIndex)-",
            crinklyCorners: corners,
            maxEdgeLengthSq: maxEdgeLength * maxEdgeLength,
            patchCache: patchCache,
            depth: 0) ?? makePatch(triangle: corners, colour: white)
        if debug {
            let stop = DispatchTime.now()
            let time = Double(stop.uptimeNanoseconds - start.uptimeNanoseconds) / 1000000000.0
            print("      Adaptive patch (\(faceIndex)): \(patch.vertices.count) vertices in \(time) s")
        }
        return makeGeometry(patch: patch, asWireframe: wireframe)
    }

    let white: Patch.Colour = [1.0, 1.0, 1.0]
    let red: Patch.Colour = [1.0, 0.0, 0.0]
    let yellow: Patch.Colour = [1.0, 1.0, 0.0]
    let cyan: Patch.Colour = [0.0, 1.0, 1.0]
    let magenta: Patch.Colour = [1.0, 0.0, 1.0]
    let grey: Patch.Colour = [0.4, 0.4, 0.4]

    private func makePatch(triangle: Triangle, colour: Patch.Colour) -> Patch {
        return Patch(vertices: triangle.vertices,
                     colours: [colour, colour, colour],
                     indices: [0, 1, 2])
    }

    private func shouldSubdivide(_ triangle: Triangle, maxEdgeLengthSq: FP) -> Bool {
        return triangle.longestEdgeSq > maxEdgeLengthSq
    }

    private func makeAdaptivePatch(name: String, crinklyCorners: Triangle, maxEdgeLengthSq: FP, patchCache: PatchCache<Patch>, depth: UInt32) -> Patch? {

        let (crinklyWorldVertices, crinklyWorldEdges, crinklyWorldDeltas) = patchCalculator.sphericallySubdivide(triangle: crinklyCorners)

        let crinklyWorldA = crinklyWorldVertices[0]
        let crinklyWorldB = crinklyWorldVertices[1]
        let crinklyWorldC = crinklyWorldVertices[2]

        let crinklyWorldTriangle = Triangle(a: crinklyWorldA, b: crinklyWorldB, c: crinklyWorldC)

        let sWorldA = SCNVector3(crinklyWorldA)
        let sWorldB = SCNVector3(crinklyWorldB)
        let sWorldC = SCNVector3(crinklyWorldC)

        guard depth < adaptivePatchMaxDepth else {
            return makePatch(triangle: crinklyWorldTriangle, colour: red)
        }

        let screenA = Patch.Vertex(scnView.projectPoint(sWorldA))
        let screenB = Patch.Vertex(scnView.projectPoint(sWorldB))
        let screenC = Patch.Vertex(scnView.projectPoint(sWorldC))

        let screenTriangle = Triangle(a: screenA, b: screenB, c: screenC)

        let normalisedScreenTriangle = screenTriangle.normalised()

        let inset: FP = debug ? 100.0 : 0.0

        if !isIntersecting(normalisedScreenTriangle, width: screenWidth, height: screenHeight, inset: inset) {

            let camera = cameraPosition
            if crinklyWorldTriangle.distanceSq(from: camera) > crinklyWorldTriangle.longestEdgeSq {

                if debug {
                    return makePatch(triangle: crinklyWorldTriangle, colour: yellow)
                } else {
                    return patchCache.read(name)
                        ?? patchCalculator.subdivide(triangle: crinklyCorners, subdivisionLevels: 0)
                }
            }
        }

        if shouldSubdivide(normalisedScreenTriangle, maxEdgeLengthSq: maxEdgeLengthSq) {
            var subVertices = [[Patch.Vertex]](repeating: [], count: 4)
            var subColours = [[Patch.Colour]](repeating: [], count: 4)
            var subIndices = [[Patch.Index]](repeating: [], count: 4)
            var hasAllSubpatches = true
            for i in 0..<crinklyWorldEdges.count {
                let index = crinklyWorldEdges[i]
                let vx = crinklyWorldVertices[Int(index[0])]
                let vy = crinklyWorldVertices[Int(index[1])]
                let vz = crinklyWorldVertices[Int(index[2])]
                let subTriangle = Triangle(a: vx, b: vy, c: vz)
                let subName = name + "\(i)"
                guard let subPatch = makeAdaptivePatch(name: subName,
                                                       crinklyCorners: subTriangle,
                                                       maxEdgeLengthSq: maxEdgeLengthSq,
                                                       patchCache: patchCache,
                                                       depth: depth + 1)
                    else {
                        hasAllSubpatches = false
                        break
                }
                subVertices[i] = subPatch.vertices
                subColours[i] = subPatch.colours
                subIndices[i] = subPatch.indices
            }
            if hasAllSubpatches {
                // TODO: pass pointers to recursive function so we don't have to copy arrays around later
                let vertices = subVertices[0] + subVertices[1] + subVertices[2] + subVertices[3]
                let colours = subColours[0] + subColours[1] + subColours[2] + subColours[3]
                var offset: UInt32 = 0
                let offsetIndices: [[Patch.Index]] = subIndices.enumerated().map { (i, s) in
                    defer { offset += UInt32(subVertices[i].count) }
                    return s.map { index in index + offset }
                }
                let indices = offsetIndices[0] + offsetIndices[1] + offsetIndices[2] + offsetIndices[3]
                return Patch(vertices: vertices, colours: colours, indices: indices)
            }
        }

        if let patch = patchCache.read(name) {
            return patch
        }

        let priority = prioritise(world: crinklyWorldTriangle, screen: normalisedScreenTriangle, delta: [crinklyWorldDeltas[0], crinklyWorldDeltas[1], crinklyWorldDeltas[2]], depth: depth)

        patchCalculator.calculate(name, triangle: crinklyCorners, subdivisions: detailSubdivisions, priority: priority) { patch in
            self.patchCache.write(name, patch: patch)
        }

        if debug {
            return makePatch(triangle: crinklyWorldTriangle, colour: magenta)
        }

        return nil
    }

    private func prioritise(world: Triangle, screen: Triangle, delta: [FP], depth: UInt32) -> Double {
        return unitClamp(Double((screen.centroid - screenCenter).lengthSq() / halfScreenWidthSq))
    }
}
