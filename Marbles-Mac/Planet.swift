import SceneKit

protocol PlanetDelegate: class {
    func project(point: SCNVector3) -> Patch.Vertex
    func isIntersectingScreen(triangle: Triangle) -> Bool
    func distanceSqFromCamera(triangle: Triangle) -> FP
    func distanceSqFromScreenCenter(triangle: Triangle) -> FP
}

class Planet {

    weak var delegate: PlanetDelegate!
    var wireframe: Bool = false

    let name: String

    private let detailSubdivisions: UInt32 = 5
    private lazy var maxEdgeLength: FP = pow(2, FP(detailSubdivisions + 2))
    private let adaptivePatchMaxDepth: UInt32 = 20

    private let planetConfig: PlanetConfig
    private var patchCache = PatchCache<Patch>()
    private let patchCalculator: PatchCalculator
    private let patchBuffer: PatchBuffer

    let terrainNode = SCNNode()
    private var nodes = [SCNNode]()
    private var geometries = [SCNGeometry]()

    init(name: String, config: PlanetConfig, patchBuffer: PatchBuffer) {
        patchCalculator = PatchCalculator(config: config)
        self.planetConfig = config
        self.name = name
        self.patchBuffer = patchBuffer
    }

    func makeTerrain() -> SCNNode {
        for faceIndex in 0..<faces.count {
            let face = faces[faceIndex]
            let triangle = Triangle(a: positions[Int(face[0])], b: positions[Int(face[1])], c: positions[Int(face[2])])
            let patch = patchCalculator.subdivide(triangle: triangle, subdivisionLevels: detailSubdivisions)
            patchCache.write("\(name)-\(faceIndex)-", patch: patch)
            let geometry = makeGeometry(patch: patch, asWireframe: wireframe)
            let node = SCNNode(geometry: geometry)
            geometries.append(geometry)
            nodes.append(node)
            terrainNode.addChildNode(node)
        }
        return terrainNode
    }

    func refreshGeometry() {
        for faceIndex in 0..<faces.count {
            let face = faces[faceIndex]
            let triangle = Triangle(a: positions[Int(face[0])], b: positions[Int(face[1])], c: positions[Int(face[2])])
            let geom = makeAdaptiveGeometry(faceIndex: faceIndex, corners: triangle, maxEdgeLength: maxEdgeLength)
            geometries[faceIndex] = geom
        }
    }

    func updateNode() {
        for faceIndex in 0..<self.nodes.count {
            self.nodes[faceIndex].geometry = self.geometries[faceIndex]
        }
    }

    private func makeAdaptiveGeometry(faceIndex: Int, corners: Triangle, maxEdgeLength: FP) -> SCNGeometry {
        let start = DispatchTime.now()
        let patch = makeAdaptivePatch(name: "\(name)-\(faceIndex)-",
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

        let translatedWorldA = terrainNode.convertPosition(SCNVector3(crinklyWorldA), to: nil)
        let translatedWorldB = terrainNode.convertPosition(SCNVector3(crinklyWorldB), to: nil)
        let translatedWorldC = terrainNode.convertPosition(SCNVector3(crinklyWorldC), to: nil)

        let screenA = delegate.project(point: translatedWorldA)
        let screenB = delegate.project(point: translatedWorldB)
        let screenC = delegate.project(point: translatedWorldC)

        let screenTriangle = Triangle(a: screenA, b: screenB, c: screenC)

        let normalisedScreenTriangle = screenTriangle.normalised()

        let translatedWorldTriangle = Triangle(a: Patch.Vertex(translatedWorldA),
                                               b: Patch.Vertex(translatedWorldB),
                                               c: Patch.Vertex(translatedWorldC))

        let distanceFromCamera = delegate.distanceSqFromCamera(triangle: translatedWorldTriangle)

        if !delegate.isIntersectingScreen(triangle: normalisedScreenTriangle) {

            if distanceFromCamera > crinklyWorldTriangle.longestEdgeSq {

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

        let priority = prioritise(screen: normalisedScreenTriangle, depth: depth, distance: distanceFromCamera)

        patchBuffer.calculate(name, triangle: crinklyCorners, subdivisions: detailSubdivisions, priority: priority, calculator: patchCalculator) { patch in
            self.patchCache.write(name, patch: patch)
        }

        if debug {
            return makePatch(triangle: crinklyWorldTriangle, colour: magenta)
        }

        return nil
    }

    private func prioritise(screen: Triangle, depth: UInt32, distance: FP) -> FP {
        let centerFactor = 1 - (delegate.distanceSqFromScreenCenter(triangle: screen).unitClamped())
        let depthFactor = 1 - (FP(depth) / FP(adaptivePatchMaxDepth)).unitClamped()
        let distanceFactor = 1 - (distance / 100).unitClamped()
        return 1 - (centerFactor * 0.4 + distanceFactor * 0.3 + depthFactor * 0.3)
    }
}
