import AppKit
import QuartzCore
import SceneKit
import SceneKit.ModelIO
import ModelIO

let seed = 315
let octaves = 10
let frequency: Double = Double(1.0 / diameter * 2.0)
let persistence = 0.5
let lacunarity = 2.0
let amplitude: Double = Double(radius / 10.0)
let levels = 0
let iciness: FP = 0.4
let brilliance: Float = 1.0

let wireframe = false
let smoothing = 0
let diameter: CGFloat = 10000.0
let radius: CGFloat = diameter / 2.0
let mountainHeight: FP = amplitude / 2.0

class MarbleViewController: NSViewController {

    let scene = SCNScene()
    let terrainNode = SCNNode()
    let terrainNoise: Noise
    let terrainQueues = [DispatchQueue](repeating: DispatchQueue(label: "terrain", qos: .userInteractive, attributes: .concurrent), count: 20)
    let lowQueue = DispatchQueue(label: "lowPatch", qos: .userInitiated, attributes: .concurrent)
    let highQueue = DispatchQueue(label: "highPatch", qos: .default, attributes: .concurrent)
    var dispatchWorkItems = NSPointerArray.weakObjects()
    var counter = 0
    var w: CGFloat!
    var h: CGFloat!
    let lowCount = AtomicInteger()
    let highCount = AtomicInteger()

    let subdividedTriangleEdges: [[UInt32]] = [[0, 3, 5], [3, 1, 4], [3, 4, 5], [5, 4, 2]]
    var cachedPatches = [[String: (UInt32, [FP3], [float3], [[UInt32]])]](repeating: [:], count: 20)

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
        p// * FP(radius)
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

    required init?(coder: NSCoder) {
        let sourceNoise = GradientNoise3D(amplitude: amplitude, frequency: frequency, seed: seed)
        terrainNoise = FBM(sourceNoise, octaves: octaves, persistence: persistence, lacunarity: lacunarity)
        super.init(coder: coder)
    }

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
//        camera.zFar = FP(diameter * 5)
//        camera.zNear = 1.0
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
        scnView.cameraControlConfiguration.flyModeVelocity = 0.5
        if wireframe {
            scnView.debugOptions = SCNDebugOptions([.renderAsWireframe])
        }
        w = scnView.bounds.width
        h = scnView.bounds.height
        print(w,h)

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

    @objc func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
        dispatchWorkItems.allObjects.forEach { object in
            let pointer = object as! UnsafeRawPointer
            let item = Unmanaged<DispatchWorkItem>.fromOpaque(pointer).takeUnretainedValue()
            item.cancel()
        }
        for _ in 0..<dispatchWorkItems.count {
            dispatchWorkItems.removePointer(at: 0)
        }
        dispatchWorkItems.compact()
    }

//    private func makeWater() {
//        let noise = GradientNoise3D(amplitude: 0.08, frequency: 100.0, seed: 31390)
//        let icosa = MDLMesh.newIcosahedron(withRadius: Float(radius), inwardNormals: false, allocator: nil)
//        let shape = MDLMesh.newSubdividedMesh(icosa, submeshIndex: 0, subdivisionLevels: 3)!
//        let water = makeCrinkly(mdlMesh: shape, noise: noise, levels: 0, smoothing: 1, offset: radius/100.0, assignColours: false)
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
            let colours = findColours(for: vertices)
            let geometry = makeGeometry(positions: vertices, colours: colours, indices: [0, 1, 2])
            let node = SCNNode(geometry: geometry)
            self.terrainNode.addChildNode(node)
            updateRoot(faceIndex: faceIndex, node: node)
        }
        self.scene.rootNode.addChildNode(terrainNode)
    }

    private func updateRoot(faceIndex: Int, node: SCNNode) {
        let item = DispatchWorkItem {
            let face = self.faces[faceIndex]
            let vertices = [self.positions[Int(face[0])], self.positions[Int(face[1])], self.positions[Int(face[2])]]
            let geom = self.makeGeometry(faceIndex: faceIndex, corners: vertices, maxEdgeLength: 500.0)
            DispatchQueue.main.async {
//                print("[\(faceIndex)] updated geometry: \(self.counter)")
                self.counter += 1
                node.geometry = geom
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.updateRoot(faceIndex: faceIndex, node: node)
                }
            }
        }
        let pointer = Unmanaged.passUnretained(item).toOpaque()
        dispatchWorkItems.addPointer(pointer)
        self.terrainQueues[faceIndex].async(execute: item)
    }

    private func makeGeometry(faceIndex: Int, corners: [FP3], maxEdgeLength: FP) -> SCNGeometry {
        let (vertices, colours, edges) = makeGeometrySources(faceIndex: faceIndex, name: "", corners: corners, maxEdgeLengthSq: maxEdgeLength * maxEdgeLength, depth: 0)
//        print(vertices)
        return makeGeometry(positions: vertices, colours: colours, indices: Array(edges.joined()))
    }

    private func makeGeometrySources(faceIndex: Int, name: String, corners: [FP3], maxEdgeLengthSq: FP, depth: UInt32) -> ([FP3], [float3], [[UInt32]]) {
        // make vertices and edges from initial corners such that no projected edge is longer
        // than maxEdgeLength
        var positions = [FP3]()
        var colours = [float3]()
        var edges = [[UInt32]]()
        let subv = sphericallySubdivide(vertices: corners, radius: FP(radius))
        var offset: UInt32 = 0
        var subdivide = false
        let scnView = view as! SCNView

        let sphericalisedCorners = sphericalise(vertices: corners, radius: FP(radius))

//        for index in subdividedTriangleEdges {
//            let v0 = subv[Int(index[0])]
//            let v1 = subv[Int(index[1])]
//            let v2 = subv[Int(index[2])]
            let v0 = sphericalisedCorners[0]
            let v1 = sphericalisedCorners[1]
            let v2 = sphericalisedCorners[2]
            let p0 = scnView.projectPoint(SCNVector3(v0))
            let p1 = scnView.projectPoint(SCNVector3(v1))
            let p2 = scnView.projectPoint(SCNVector3(v2))

//        print()
//        print(maxEdgeLengthSq)
//        print(v0, v1, v2)
//        print(p0, p1, p2)

        if intersectsScreen(p0, p1, p2) {
            let l0 = FP((p0 - p1).lengthSq())
            let l1 = FP((p0 - p2).lengthSq())
            let l2 = FP((p1 - p2).lengthSq())
//            print(l0, l1, l2)
            let dumbLength: FP = 1000000000
            if (l0 > maxEdgeLengthSq || l1 > maxEdgeLengthSq || l2 > maxEdgeLengthSq) &&
                (l0 < dumbLength && l1 < dumbLength && l2 < dumbLength) {
                subdivide = true
//                break
            }
        }
//    }
        let maxDepth = 50
        if depth >= maxDepth {
            print("hit max depth \(maxDepth)")
            return (positions, colours, edges)
            // TODO: hitting max depth seems to cause massive number of patch dispatch items
        }
        if subdivide {
            var newpositions = [[FP3]](repeating: [], count: 4)
            var newcolours = [[float3]](repeating: [], count: 4)
            var newindices = [[[UInt32]]](repeating: [], count: 4)
            for i in 0..<subdividedTriangleEdges.count {
                let index = subdividedTriangleEdges[i]
                let vx = subv[Int(index[0])]
                let vy = subv[Int(index[1])]
                let vz = subv[Int(index[2])]
                let subname = name + "\(i)"
                let (iv, ic, ii) = makeGeometrySources(faceIndex: faceIndex, name: subname, corners: [vx, vy, vz], maxEdgeLengthSq: maxEdgeLengthSq, depth: depth+1)
                newpositions[i] = iv
                newcolours[i] = ic
                newindices[i] = ii
            }
            for i in 0..<4 {
                positions.append(contentsOf: newpositions[i])
                let offsetEdges = newindices[i].map { edges in
                    edges.map { edge in edge + offset }
                }
                offset += UInt32(newpositions[i].count)
                colours.append(contentsOf: newcolours[i])
                edges.append(contentsOf: offsetEdges)
            }
        } else {
            if let (depth, cv, cc, ci) = cachedPatches[faceIndex][name] {
//                print("cache hit \(name)")
                positions.append(contentsOf: cv)
                colours.append(contentsOf: cc)
                edges.append(contentsOf: ci)
            } else {
//                print("miss \(name)")
                let sphericalisedColours = findColours(for: sphericalisedCorners)
                positions.append(contentsOf: sphericalisedCorners)
                colours.append(contentsOf: sphericalisedColours)
                edges.append([0, 1, 2])
                let itemLow = makePatchItem(subdivisions: 4, low: true, corners: corners, faceIndex: faceIndex, name: name)
                let itemHigh = makePatchItem(subdivisions: 7, low: false, corners: corners, faceIndex: faceIndex, name: name)
                lowCount.incrementAndGet()
                lowQueue.async(execute: itemLow)
                highCount.incrementAndGet()
                highQueue.async(execute: itemHigh)
//                let pointerLow = Unmanaged.passUnretained(itemLow).toOpaque()
//                dispatchWorkItems.addPointer(pointerLow)
//                let pointerHigh = Unmanaged.passUnretained(itemHigh).toOpaque()
//                dispatchWorkItems.addPointer(pointerHigh)
            }
        }
        return (positions, colours, edges)
    }

    private func makePatchItem(subdivisions: UInt32, low: Bool, corners: [FP3], faceIndex: Int, name: String) -> DispatchWorkItem {
        let item = DispatchWorkItem {
            if let item = self.cachedPatches[faceIndex][name] {//TODO: race cpndition
                if item.0 >= subdivisions {
                    let c: Int
                    if low {
                        c = self.lowCount.decrementAndGet()
                    } else {
                        c = self.highCount.decrementAndGet()
                    }
                    print("\(self.lowCount.get()), \(self.highCount.get()): bail")
                    return
                }
            }
            let (subv, subc, subii) = self.subdivideTriangle(vertices: corners, subdivisionLevels: subdivisions)
            let c: Int
            if low {
                c = self.lowCount.decrementAndGet()
            } else {
                c = self.highCount.decrementAndGet()
            }
            print("\(self.lowCount.get()), \(self.highCount.get()): bail")
            DispatchQueue.main.async {
                self.cachedPatches[faceIndex][name] = (subdivisions, subv, subc, subii)
            }
        }
        return item
    }

    private func intersectsScreen(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) -> Bool {
        let minX = min(a.x, b.x, c.x)
        let maxX = max(a.x, b.x, c.x)
        let minY = min(a.y, b.y, c.y)
        let maxY = max(a.y, b.y, c.y)
        let inset: CGFloat = 0.0
        let overlapsX = minX <= (w + inset) && maxX >= (0 - inset)
        let overlapsY = minY <= (h + inset) && maxY >= (0 - inset)
        // TODO: clip those facing away from screen?
        return overlapsX && overlapsY
    }

    private func makeGeometry(positions: [FP3], colours: [float3], indices: [[UInt32]]) -> SCNGeometry {
        return makeGeometry(positions: positions, colours: colours, indices: Array(indices.joined()))
    }

    private func adjusted(colour: float3) -> float3 {
        return colour * brilliance
    }

    private func findColours(for positions: [FP3]) -> [float3] {
        var colours = [float3]()
        for p in positions {
            let pn = normalize(p) * FP(radius)
            let delta = length(p) - length(pn)
            let distanceFromEquator: FP = abs(p.y)/FP(radius)
            let dryness: FP = 1 - iciness
            let snowLine = FP(mountainHeight * 1.5) * (1 - distanceFromEquator * iciness) * dryness
            let rawHeightColour = FP(delta) / mountainHeight
            let heightColour = Float(scaledUnitClamp(rawHeightColour, min: 0.15))
            if FP(delta) > snowLine {
                // Ice
                colours.append(adjusted(colour: [1.0, 1.0, 1.0]))
            } else if FP(delta) >= 0.0 && FP(delta) < mountainHeight / 10.0 {
                // Beach
                colours.append(adjusted(colour: [1.0, 1.0, 0.0]))
            } else if FP(delta) < 0.0 {
                // Error
                colours.append(adjusted(colour: [1.0, 0.0, 0.0]))
            } else {
                // Forest
                colours.append(adjusted(colour: [0.0, heightColour, 0.0]))
            }
        }
        return colours
    }

    private func makeGeometry(positions: [FP3], colours: [float3], indices: [UInt32]) -> SCNGeometry {
        let vertices = positions.map { SCNVector3($0[0], $0[1], $0[2])}
        let positionSource = SCNGeometrySource(vertices: vertices)

        let colourData = NSData(bytes: colours, length: MemoryLayout<float3>.size * colours.count)
        let colourSource = SCNGeometrySource(data: colourData as Data, semantic: .color, vectorCount: colours.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: MemoryLayout<float3>.size)

        var sources = [positionSource]
        if !wireframe {
            sources.append(colourSource)
        }

        let edgeElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let start = DispatchTime.now()
        let geometry = SCNGeometry(sources: sources, elements: [edgeElement])
        let stop = DispatchTime.now()
        let elapsed = stop.uptimeNanoseconds - start.uptimeNanoseconds
//        print("   \(elapsed)")
        return geometry
    }

    private func sphericalise(vertices: [FP3], radius: FP) -> [FP3] {
        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]
        let `as` = spherical(a, radius: radius, noise: terrainNoise)
        let bs = spherical(b, radius: radius, noise: terrainNoise)
        let cs = spherical(c, radius: radius, noise: terrainNoise)
        return [`as`, bs, cs]
    }

    private func sphericallySubdivide(vertices: [FP3], radius: FP) -> [FP3] {

        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]

        let ab = midway(a, b)
        let bc = midway(b, c)
        let ca = midway(c, a)

        let `as` = spherical(a, radius: radius, noise: terrainNoise)
        let bs = spherical(b, radius: radius, noise: terrainNoise)
        let cs = spherical(c, radius: radius, noise: terrainNoise)
        let abs = spherical(ab, radius: radius, noise: terrainNoise)
        let bcs = spherical(bc, radius: radius, noise: terrainNoise)
        let cas = spherical(ca, radius: radius, noise: terrainNoise)

        return [`as`, bs, cs, abs, bcs, cas]
    }

    private func spherical(_ a: FP3, radius: FP, noise: Noise) -> FP3 {
        let an = normalize(a)
        let ans = an * radius
        var delta = noise.evaluate(Double(ans.x), Double(ans.y), Double(ans.z))
        if levels > 0 {
            let ratio = Double(amplitude) / Double(levels)
            delta = ratio * round(delta / ratio)
        }
        return an * (radius + delta)
    }

    private func subdivideTriangle(vertices: [FP3], subdivisionLevels: UInt32) -> ([FP3], [float3], [[UInt32]]) {

        let a = spherical(vertices[0], radius: FP(radius), noise: terrainNoise)
        let b = spherical(vertices[1], radius: FP(radius), noise: terrainNoise)
        let c = spherical(vertices[2], radius: FP(radius), noise: terrainNoise)

        let segments = pow(2, subdivisionLevels)

        let dab = b - a
        let lab = length(dab)
        let slab = lab / FP(segments)
        let vab = normalize(dab) * slab

        let dbc = c - b
        let lbc = length(dbc)
        let slbc = lbc / FP(segments)
        let vbc = normalize(dbc) * slbc

        var next: UInt32 = 0
        var faces = [[UInt32]]()
        var points = [FP3]()
        points.append(a)
        for j in 1...segments {
            let p = a + (vab * FP(j))
            let ps = spherical(p, radius: FP(radius), noise: terrainNoise)
            points.append(ps)
            for i in 1...j {
                let q = p + (vbc * FP(i))
                let qs = spherical(q, radius: FP(radius), noise: terrainNoise)
                points.append(qs)
                if i < j {
                    faces.append([next, next+j, next+j+1])
                    faces.append([next, next+j+1, next+1])
                    next += 1
                }
            }
            faces.append([next, next+j, next+j+1])
            next += 1
        }

        let colours = findColours(for: points)

        return (points, colours, faces)
    }
}

/*

 main loop: when camera/scene stops moving, or once per second, etc.):

 cancel everything in priority queue
 bestdepth = calculate number of divisions needed to make nearest triangle less than max edge length
 subdivide all visible triangles to bestdepth
 leaf triangles should show best subdivision patch available (possibly 0, or otherwise cached)
 for those leaves not at max subdivision add them to priority queue in order of distance from camera

 priority queue:

 ordered by distance from camera and subdivision level?
 want visible differences asap, but prioritise everything at same subdivision level over distance from camera ("breadth-first")

 */

public class AtomicInteger {

    private let lock = DispatchSemaphore(value: 1)
    private var value = 0

    // You need to lock on the value when reading it too since
    // there are no volatile variables in Swift as of today.
    public func get() -> Int {

        lock.wait()
        defer { lock.signal() }
        return value
    }

    public func set(_ newValue: Int) {

        lock.wait()
        defer { lock.signal() }
        value = newValue
    }

    public func incrementAndGet() -> Int {

        lock.wait()
        defer { lock.signal() }
        value += 1
        return value
    }

    public func decrementAndGet() -> Int {

        lock.wait()
        defer { lock.signal() }
        value -= 1
        return value
    }
}
