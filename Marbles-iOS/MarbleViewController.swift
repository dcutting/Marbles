import UIKit
import SceneKit

let debug = false

class MarbleViewController: UIViewController {

    let planet = earthConfig
    let detailSubdivisions: UInt32 = 5
    lazy var maxEdgeLength = FP(pow(2, detailSubdivisions + 1))
    let adaptivePatchMaxDepth: UInt32 = 15
    let updateInterval = 0.2
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

    var screenWidth: CGFloat = 0.0
    var halfScreenWidthSq: CGFloat = 0.0
    var screenHeight: CGFloat = 0.0
    var screenCenter = SCNVector3()
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

        scene.background.contents = UIImage(named: "tycho")!

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
        ambientLight.color = UIColor(white: 0.1, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true
        let cameraNode = SCNNode()
        cameraNode.position = SCNVector3(x: 0.0, y: 0.0, z: Float(CGFloat(planet.radius * 2.5)))
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
            self.adaptFlyingSpeed()
        }

        let clickGesture = UITapGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        let doubleClickGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.numberOfTapsRequired = 2
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers?.insert(clickGesture, at: 0)
        gestureRecognizers?.insert(doubleClickGesture, at: 1)
        scnView.gestureRecognizers = gestureRecognizers
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBounds()
    }

    private func updateBounds() {
        screenWidth = view.bounds.width
        screenHeight = view.bounds.height
        halfScreenWidthSq = (screenWidth / 2.0) * (screenWidth / 2.0)
        screenCenter = SCNVector3(screenWidth / 2.0, screenHeight / 2.0, 0.0)
    }

    @objc func handleClick(_ gestureRecognizer: UITapGestureRecognizer) {
        let scnView = view as! SCNView
        let mode = scnView.defaultCameraController.interactionMode
        scnView.defaultCameraController.interactionMode = mode == .fly ? .orbitCenteredArcball : .fly
    }

    @objc func handleDoubleClick(_ gestureRecognizer: UITapGestureRecognizer) {
        wireframe.toggle()
    }

    private func adaptFlyingSpeed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let distance = self.scnView.defaultCameraController.pointOfView!.position.length()
            let zeroHeight = self.planet.radius * 0.99
            let newVelocity = ((FP(distance) - zeroHeight) / zeroHeight) * zeroHeight / 10.0
            self.scnView.cameraControlConfiguration.flyModeVelocity = CGFloat(newVelocity)
            self.adaptFlyingSpeed()
        }
    }

    var nodes = [SCNNode]()
    var geometries = [SCNGeometry]()

    private func makeTerrain() {
        for faceIndex in 0..<faces.count {
            let face = faces[faceIndex]
            let vertices = [positions[Int(face[0])], positions[Int(face[1])], positions[Int(face[2])]]
            let patch = patchCalculator.subdivideTriangle(vertices: vertices, subdivisionLevels: detailSubdivisions)
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
            if debug {
                print("  Clearing priority buffer")
            }
            self.patchCalculator.clearBuffer()
            // TODO: don't calculate invisible faces
            for faceIndex in 0..<faces.count {
                if debug {
                    print("    Starting adaptive terrain generation for face \(faceIndex)")
                }
                let face = faces[faceIndex]
                let vertices = [positions[Int(face[0])], positions[Int(face[1])], positions[Int(face[2])]]
                if let geom = self.makeAdaptiveGeometry(faceIndex: faceIndex, corners: vertices, maxEdgeLength: self.maxEdgeLength) {
                    self.geometries[faceIndex] = geom
                }
            }
            DispatchQueue.main.sync {
                if debug {
                    print("* Refreshing geometry")
                }
                for faceIndex in 0..<self.nodes.count {
                    self.nodes[faceIndex].geometry = self.geometries[faceIndex]
                }

                self.refreshGeometry()
            }
        }
    }

    private func makeAdaptiveGeometry(faceIndex: Int, corners: [FP3], maxEdgeLength: FP) -> SCNGeometry? {
        let cameraPosition = (view as! SCNView).defaultCameraController.pointOfView!.position
        let distanceSq = cameraPosition.lengthSq()
        guard isVisible(vertices: corners, cameraPosition: cameraPosition, distanceSq: distanceSq)
            else { return nil }
        let start = DispatchTime.now()
        let patch = makeAdaptivePatch(name: "\(faceIndex)-",
            corners: corners,
            maxEdgeLengthSq: maxEdgeLength * maxEdgeLength,
            patchCache: patchCache,
            depth: 0) ?? makePatch(vertices: corners, colour: grey)
        if debug {
            let stop = DispatchTime.now()
            print("      Adaptive patch (\(faceIndex)): \(patch.vertices.count) vertices in \(stop.uptimeNanoseconds - start.uptimeNanoseconds)")
        }
        return makeGeometry(patch: patch, asWireframe: wireframe)
    }

    private func isVisible(vertices: [FP3], cameraPosition: SCNVector3, distanceSq: CGFloat) -> Bool {
        // Cull triangles on other side of planet
        let aD = (SCNVector3(vertices[0]) - cameraPosition).lengthSq()
        let bD = (SCNVector3(vertices[1]) - cameraPosition).lengthSq()
        let cD = (SCNVector3(vertices[2]) - cameraPosition).lengthSq()
        let minimumTriangleDistance = min(aD, bD, cD)
        return minimumTriangleDistance < distanceSq
    }

    let dumbLength: FP = 10000000000
    let epsilon: FP = 0.0000001
    let white: Patch.Colour = [1.0, 1.0, 1.0]
    let red: Patch.Colour = [1.0, 0.0, 0.0]
    let yellow: Patch.Colour = [1.0, 1.0, 0.0]
    let magenta: Patch.Colour = [1.0, 0.0, 1.0]
    let grey: Patch.Colour = [0.01, 0.01, 0.01]

    private func makePatch(vertices: [Patch.Vertex], colour: Patch.Colour) -> Patch {
        return Patch(vertices: vertices,
                     colours: [colour, colour, colour],
                     indices: [0, 1, 2])
    }

    private func shouldSubdivide(_ pA: SCNVector3, _ pB: SCNVector3, _ pC: SCNVector3, maxEdgeLengthSq: FP) -> Bool {
        let lA = FP((pA - pB).lengthSq())
        let lB = FP((pA - pC).lengthSq())
        let lC = FP((pB - pC).lengthSq())
        return lA > maxEdgeLengthSq && lB > maxEdgeLengthSq && lC > maxEdgeLengthSq
    }

    private func makeAdaptivePatch(name: String, corners: [FP3], maxEdgeLengthSq: FP, patchCache: PatchCache<Patch>, depth: UInt32) -> Patch? {

        guard depth < adaptivePatchMaxDepth else {
            return makePatch(vertices: corners, colour: red)
        }

        let (subv, sube, deltas) = patchCalculator.sphericallySubdivide(vertices: corners)

        let worldA = SCNVector3(subv[0])
        let worldB = SCNVector3(subv[1])
        let worldC = SCNVector3(subv[2])

        let screenA = scnView.projectPoint(worldA)
        let screenB = scnView.projectPoint(worldB)
        let screenC = scnView.projectPoint(worldC)

        guard isIntersecting(screenA, screenB, screenC, width: screenWidth, height: screenHeight) else {
            if debug {
                return makePatch(vertices: corners, colour: yellow)
            } else {
                return patchCache.read(name)
                    ?? patchCalculator.subdivideTriangle(vertices: corners, subdivisionLevels: 0)
            }
        }

        //        if depth > 10 {
        //        var str = ""
        //        for _ in 0..<depth {
        //            str += " "
        //        }
        //        str += "> \(name)"
        //        print(str)
        //            print("deep")
        //        }

        if shouldSubdivide(screenA, screenB, screenC, maxEdgeLengthSq: maxEdgeLengthSq) {
            var subVertices = [[Patch.Vertex]](repeating: [], count: 4)
            var subColours = [[Patch.Colour]](repeating: [], count: 4)
            var subIndices = [[Patch.Index]](repeating: [], count: 4)
            var hasAllSubpatches = true
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

        let priority = prioritise(world: [worldA, worldB, worldC], screen: [screenA, screenB, screenC], delta: [deltas[0], deltas[1], deltas[2]], depth: depth)

        patchCalculator.calculate(name, vertices: corners, subdivisions: detailSubdivisions, priority: priority) { patch in
            self.patchCache.write(name, patch: patch)
        }

        if debug {
            return makePatch(vertices: corners, colour: magenta)
        }

        return nil
    }

    private func prioritise(world: [SCNVector3], screen: [SCNVector3], delta: [FP], depth: UInt32) -> Double {

        let coastlineWeight = 0.35
        let landWeight = 0.3
        let depthWeight = 0.2
        let worldDistanceWeight = 0.1
        let screenDistanceWeight = 0.05

        let isAllLand = delta[0] > 0.0 && delta[1] > 0.0 && delta[2] > 0.0
        let isAllWater = delta[0] < 0.0 && delta[1] < 0.0 && delta[2] < 0.0

        let coastlineFactor = !(isAllLand || isAllWater) ? 1.0 : 0.0

        let landFactor = isAllLand ? 1.0 : 0.0

        let depthFactor = Double(adaptivePatchMaxDepth - depth) / Double(adaptivePatchMaxDepth)

        let cameraPosition = (view as! SCNView).defaultCameraController.pointOfView!.position
        let worldCentroid = centroid(of: world)
        let worldDistanceFactor = 1 - unitClamp(Double((worldCentroid - cameraPosition).lengthSq()) / planet.diameterSq)

        let screenCentroid = centroid(of: screen)
        let screenDistanceFactor = 1 - unitClamp(Double((screenCentroid - screenCenter).lengthSq() / halfScreenWidthSq))

        let coastlineComponent = coastlineFactor * coastlineWeight
        let landComponent = landFactor * landWeight
        let depthComponent = depthFactor * depthWeight
        let worldComponent = Double(worldDistanceFactor) * worldDistanceWeight
        let screenComponent = Double(screenDistanceFactor) * screenDistanceWeight

        let priorityFactor = coastlineComponent + landComponent + depthComponent + worldComponent + screenComponent
        let priority = 1 - priorityFactor

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

        return priority
    }
}
