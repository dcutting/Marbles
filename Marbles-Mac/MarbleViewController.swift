import AppKit
import SceneKit

let debug = false

class MarbleViewController: NSViewController {

    let planet = earthConfig
    let detailSubdivisions: UInt32 = 5
    lazy var maxEdgeLength: FP = FP(pow(2, detailSubdivisions + 2))
    let adaptivePatchMaxDepth: UInt32 = 20
    let updateInterval = 0.1
    let hasDays = false
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
        light.type = .directional
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.rotation = SCNVector4(-1, 1, 0, 3.14/3.0)
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
        return cameraPosition.length()
    }

    private func adaptFlyingSpeed() {
        let distance = self.cameraPosition.length()
        let zeroHeight = self.planet.radius * 1.0
        let newVelocity = ((FP(distance) - zeroHeight) / zeroHeight) * zeroHeight / 4.0
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
        return triangle.longestEdge > sqrt(maxEdgeLengthSq)
    }

    private func extrude(triangle: Triangle, to: FP) -> Triangle {
        let a = patchCalculator.sphericalBase(triangle.a, plus: to)
        let b = patchCalculator.sphericalBase(triangle.b, plus: to)
        let c = patchCalculator.sphericalBase(triangle.c, plus: to)
        return Triangle(a: a, b: b, c: c)
    }

    private func isUnderHorizon(triangle: Triangle) -> Bool {

//        let facingFactor = triangle.facingFactor(to: cameraPosition)
//
//        if facingFactor < 0.5 { return false }

        let heightSq = cameraPosition.lengthSq()
        let r = planet.radius + planet.mountainHeight
        let radiusSq = r * r
        let dSq = heightSq - radiusSq
        let d = sqrt(dSq)

        let extrudedTriangle = extrude(triangle: triangle, to: planet.mountainHeight)
        return extrudedTriangle.distance(from: cameraPosition) < d

//        for corner in corners {
//            let c: Patch.Vertex = [FP(corner.x), FP(corner.y), FP(corner.z)]
//            let sb = patchCalculator.sphericalBase(c, plus: planet.mountainHeight)
//            let ssb = SCNVector3(sb)
//            let cd = ssb.distance(to: camera)
//            if cd < d {
//                return true
//            }
//            let highest = patchCalculator.sphericalBase(c, plus: planet.mountainHeight)
//            if isUnderHorizon(vertex: SCNVector3(highest), camera: camera) {
//                return true
//            }
//        }
//        return false
    }

//    private func isUnderHorizon(vertex: SCNVector3, camera: SCNVector3) -> Bool {
//        let v = SCNVector3()
////        if camera.distance(to: vertex) < camera.distance(to: v) {
////            return true
////        }
//        let d = v.distance(to: (vertex, camera))
//        return d >= CGFloat(planet.minimumRadius)
//    }

    private func makeAdaptivePatch(name: String, crinklyCorners: Triangle, maxEdgeLengthSq: FP, patchCache: PatchCache<Patch>, depth: UInt32) -> Patch? {

//        let sBaseA = SCNVector3(flatWorldA)
//        let sBaseB = SCNVector3(flatWorldB)
//        let sBaseC = SCNVector3(flatWorldC)

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

//        guard isUnderHorizon(corners: [sBaseA, sBaseB, sBaseC]) else {
//            return makePatch(vertices: [worldA, worldB, worldC], colour: cyan)
//        }

//        let baseScreenA = scnView.projectPoint(sBaseA)
//        let baseScreenB = scnView.projectPoint(sBaseB)
//        let baseScreenC = scnView.projectPoint(sBaseC)

        let screenA = Patch.Vertex(scnView.projectPoint(sWorldA))
        let screenB = Patch.Vertex(scnView.projectPoint(sWorldB))
        let screenC = Patch.Vertex(scnView.projectPoint(sWorldC))

        let screenTriangle = Triangle(a: screenA, b: screenB, c: screenC)

        let normalisedScreenTriangle = screenTriangle.normalised()

//        if isStraddlingZ(screenTriangle) {
//            let longestEdge = screenTriangle.longestEdge
////            print(longestEdge)
//            if longestEdge > 200000 {
//                return makePatch(triangle: crinklyWorldTriangle, colour: cyan)
//            }
//        }

//        guard allZsUnclipped(screenTriangle) else {
//            return makePatch(triangle: crinklyWorldTriangle, colour: grey)
//        }

        let inset: FP = debug ? 100.0 : 0.0

        if !isIntersecting(normalisedScreenTriangle, width: screenWidth, height: screenHeight, inset: inset) {

//            if !isUnderHorizon(triangle: crinklyWorldTriangle) {

            let camera = cameraPosition
//            let facingFactor = crinklyWorldTriangle.facingFactor(to: camera)

            if crinklyWorldTriangle.distance(from: camera) > crinklyWorldTriangle.longestEdge {//} && facingFactor < 0.9 {

//            let maxWorldA = patchCalculator.sphericalBase(crinklyCorners.a, plus: planet.mountainHeight)
//            let maxWorldB = patchCalculator.sphericalBase(crinklyCorners.b, plus: planet.mountainHeight)
//            let maxWorldC = patchCalculator.sphericalBase(crinklyCorners.c, plus: planet.mountainHeight)
//
//            let maxScreenA = Patch.Vertex(scnView.projectPoint(SCNVector3(maxWorldA)))
//            let maxScreenB = Patch.Vertex(scnView.projectPoint(SCNVector3(maxWorldB)))
//            let maxScreenC = Patch.Vertex(scnView.projectPoint(SCNVector3(maxWorldC)))
//
//            let maxScreenTriangle = Triangle(a: maxScreenA, b: maxScreenB, c: maxScreenC)
//
//            let maxNormalisedScreenTriangle = maxScreenTriangle.normalised()
//
//            if !isIntersecting(maxScreenTriangle, width: screenWidth, height: screenHeight, inset: inset) {

//            if normalisedScreenTriangle.longestEdge < screenWidth {

                if debug {
                    if normalisedScreenTriangle != screenTriangle {
                        print(crinklyWorldTriangle)
                        print(screenTriangle)
                        print(normalisedScreenTriangle)
                        print()
                    }
    //                if isStraddlingZ(screenTriangle) {
    //                    let longestEdge = screenTriangle.longestEdge
    //                    print(crinklyWorldTriangle)
    //                    print(screenTriangle)
    //                    print(longestEdge)
    //                }
                    return makePatch(triangle: crinklyWorldTriangle, colour: yellow)
                } else {
                    return patchCache.read(name)
                        ?? patchCalculator.subdivide(triangle: crinklyCorners, subdivisionLevels: 0)
                }
            }
        }

//        if screenA.z < 0.0 || screenA.z > 1.0 || screenB.z < 0.0 || screenB.z > 1.0 || screenC.z < 0.0 || screenC.z > 1.0 {
//            print(screenA)
//            print(screenB)
//            print(screenC)
//            print()
//        }
//        if screenB.z < 0.0 || screenB.z > 1.0 {
//            print("screenB: \(screenB)")
//        }
//        if screenC.z < 0.0 || screenC.z > 1.0 {
//            print("screenC: \(screenC)")
//        }

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

//        let coastlineWeight = 0.3
//        let landWeight = 0.2
//        let depthWeight = 0.35
//        let worldDistanceWeight = 0.1
//        let screenDistanceWeight = 0.05
//
//        let isAllLand = delta[0] > 0.0 && delta[1] > 0.0 && delta[2] > 0.0
//        let isAllWater = delta[0] < 0.0 && delta[1] < 0.0 && delta[2] < 0.0
//
//        let coastlineFactor = !(isAllLand || isAllWater) ? 1.0 : 0.0
//
//        let landFactor = isAllLand ? 1.0 : 0.0
//
//        let depthFactor = Double(adaptivePatchMaxDepth - depth) / Double(adaptivePatchMaxDepth)
//
//        let worldDistanceFactor = 1 - unitClamp(Double((world.centroid - cameraPosition).lengthSq()) / planet.diameterSq)
//
        let screenDistanceFactor = 1 - unitClamp(Double((screen.centroid - screenCenter).lengthSq() / halfScreenWidthSq))
        return 1-screenDistanceFactor

//        let forward = scnView.defaultCameraController.pointOfView!.worldFront
//        let speed = 2000//scnView.cameraControlConfiguration.flyModeVelocity
//        let projectedPosition = cameraPosition + Patch.Vertex(forward) * FP(speed)
//        let facingFactor = (world.facingFactor(to: projectedPosition) - 1.0) / -2.0
//        return facingFactor

//        let coastlineComponent = coastlineFactor * coastlineWeight
//        let landComponent = landFactor * landWeight
//        let depthComponent = depthFactor * depthWeight
//        let worldComponent = Double(worldDistanceFactor) * worldDistanceWeight
//        let screenComponent = Double(screenDistanceFactor) * screenDistanceWeight
//
//        let priorityFactor = coastlineComponent + landComponent + depthComponent + worldComponent + screenComponent
//        let priority = 1 - priorityFactor

//        if debug {
//            print(world)
//            print(screen)
//            print(depth, cameraPosition, screenCenter)
//            print(worldCentroid, worldDistanceFactor)
//            print(screenCentroid, screenDistanceFactor)
//            print(coastlineFactor, depthFactor, worldDistanceFactor, screenDistanceFactor)
//            print(coastlineComponent, depthComponent, worldComponent, screenComponent)
//            print(priorityFactor, priority)
//            print()
//        }

//        return priority
    }
}
