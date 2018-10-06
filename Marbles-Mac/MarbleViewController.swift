import AppKit
import QuartzCore
import SceneKit

class MarbleViewController: NSViewController {

    let power = { (x: UInt32, y: UInt32) -> UInt32 in
        var result: UInt32 = 1
        for i in 0..<y {
            result *= x
        }
        return result
    }

    let edgeness: CGFloat = 10.0
    let smoothness: CGFloat = 2.0
    let subdivision = 0
    let n: UInt32 = 8
    lazy var ticks: UInt32 = power(2, n) + 1
    let width: CGFloat = 10.0
    lazy var halfWidth: CGFloat = width / 2.0

    var segmentCount = 3

    let scene = SCNScene()
    var terrainNode: SCNNode?

    let perlinGranularity = 10
    lazy var perlin = PerlinMesh(n: perlinGranularity, seed: 1780680306855649768)

    func conv(_ i: UInt32, _ j: UInt32) -> UInt32 {
        return j * self.ticks + i
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scene.fogColor = NSColor.black
        scene.fogStartDistance = width*2.0
        scene.fogEndDistance = width*5.0

        SCNTransaction.animationDuration = 1.0

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: halfWidth, z: halfWidth)
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .directional
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.look(at: SCNVector3())
        lightNode.position = SCNVector3(x: 0, y: 20, z: 20)
//        lightNode.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: 60)))
        scene.rootNode.addChildNode(lightNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.1, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        updateTerrain()

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        scnView.backgroundColor = NSColor.black

        // Add a click gesture recognizer
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        var gestureRecognizers = scnView.gestureRecognizers
        gestureRecognizers.insert(clickGesture, at: 0)
//        scnView.gestureRecognizers = gestureRecognizers
    }

    private func updateTerrain() {
//        let terrain = generateDiamondSquareTerrain()
        let terrain = generateFlatTerrain()
        let geometry = generateMesh(fromTerrain: terrain)
//        let geometry = generateSphere(segmentCount: segmentCount)

//        let geometry = generateTriangle()
//        printVertices(for: geometry)
//        geometry.firstMaterial?.fillMode = .lines
        geometry.firstMaterial?.fillMode = .fill
        geometry.wantsAdaptiveSubdivision = subdivision > 0 ? true : false
        geometry.subdivisionLevel = subdivision
        terrainNode?.removeFromParentNode()
        let mesh = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(mesh)
        terrainNode = mesh
    }

    private func generateTriangle() -> SCNGeometry {
//        let terrain = generateTriangularTerrain(maxDivisions: 4, corners: [
//                1.0, 0.0, 0.0
//            ])
//        print(terrain)
        return makeTriMesh(corners: [0.0, 0.0, 0.0], depth: 1, radius: width/2.0)
    }

    private func printVertices(for geometry: SCNGeometry) {
        let vertices = geometry.vertices()
        for vertex in vertices! {
            print(vertex)
        }
        print(vertices!.count)
    }

    private func generateSphere(segmentCount: Int) -> SCNGeometry {
        let geometry = SCNSphere(radius: 3.0)
        geometry.segmentCount = segmentCount
        geometry.isGeodesic = true
        return geometry
    }

    @objc
    func handleClick(_ gestureRecognizer: NSGestureRecognizer) {
        segmentCount += 1
        self.updateTerrain()
    }

    private func generateRandomTerrain() -> [CGFloat] {
        var terrain = [CGFloat]()
        for _ in 0..<ticks*ticks {
            let height = CGFloat.random(in: -0.1...0.5)
            terrain.append(height)
        }
        return terrain
    }

    private func generateFlatTerrain() -> [CGFloat] {
        var terrain: [CGFloat] = Array(repeating: 0.0, count: Int(ticks*ticks))
        let n = UInt32(ticks)
        let blah = Float(width)/Float(ticks)
        let noise1 = GradientNoise2D(amplitude: 1.0, frequency: 0.2, seed: 313910)
        let noise2 = GradientNoise2D(amplitude: 0.2, frequency: 1.0, seed: 31390)
        let noise3 = GradientNoise2D(amplitude: 0.005, frequency: 10.0, seed: 3110)
        for j in 0..<n {
            for i in 0..<n {
                let x = (blah * Float(i)) / Float(width) * Float(perlinGranularity-1)
                let y = (blah * Float(j)) / Float(width) * Float(perlinGranularity-1)
//                let noise = perlin.noise(x: x, y: y)
                let noise = noise1.evaluate(Double(x), Double(y))//r +
                    //noise2.evaluate(Double(x), Double(y)) +
                    ////noise3.evaluate(Double(x), Double(y))
//                print(i, j, x, y, noise)
                terrain[Int(conv(j, i))] = CGFloat(noise)
            }
        }
        return terrain
    }

    private func generateDiamondSquareTerrain() -> [CGFloat] {
        var terrain: [CGFloat] = Array(repeating: 0.0, count: Int(ticks*ticks))

        let fullLength = ticks - 1

        let delta = width/edgeness
        let range: ClosedRange<CGFloat> = -delta...delta
        terrain[Int(conv(0, 0))] = CGFloat.random(in: range)
        terrain[Int(conv(fullLength, fullLength))] = CGFloat.random(in: range)
        terrain[Int(conv(fullLength, 0))] = CGFloat.random(in: range)
        terrain[Int(conv(0, fullLength))] = CGFloat.random(in: range)

        var numSquares: UInt32 = 1
        while numSquares < fullLength {
            let squareLength = fullLength / numSquares
            let halfSquareLength = squareLength / 2

            // Square step
            for j in 0..<numSquares {
                for i in 0..<numSquares {
                    let x = i * squareLength + halfSquareLength
                    let y = j * squareLength + halfSquareLength
                    let index = conv(x, y)
                    let corners = [
                        terrain[Int(conv(i*squareLength,j*squareLength))],
                        terrain[Int(conv((i+1)*squareLength,(j+1)*squareLength))],
                        terrain[Int(conv(i*squareLength,(j+1)*squareLength))],
                        terrain[Int(conv((i+1)*squareLength,j*squareLength))]
                    ]
                    let sum = corners.reduce(0) { a, x in a + x }
                    let average = sum / CGFloat(corners.count)
                    let delta = width/CGFloat(numSquares)/smoothness
                    let random = CGFloat.random(in: -delta...delta)
                    let newHeight = average + random
                    terrain[Int(index)] = newHeight
                }
            }

            // Diamond step
            let steps: Int = Int(2 * numSquares + 1)
            for j: Int in 0..<steps {
                for i: Int in 0..<steps {
                    if (j % 2 == 0 && i % 2 != 0) || (j % 2 != 0 && i % 2 == 0) {
                        let x = UInt32(i) * halfSquareLength
                        let y = UInt32(j) * halfSquareLength
                        let index = conv(x, y)
                        //                        print(numSquares, steps, i, j, x, y, index)
                        let pairs: [(Int, Int)] = [ (i, j-1), (i-1, j), (i, j+1), (i+1, j)]
                        let validPairs = pairs.filter { (a, b) in
                            a >= 0 && a < steps && b >= 0 && b < steps
                        }
                        let corners = validPairs.map { arg -> UInt32 in
                            let (a, b) = arg
                            return conv(UInt32(a)*halfSquareLength, UInt32(b)*halfSquareLength)
                        }
                        let values = corners.filter { $0 >= 0 && $0 < ticks*ticks }.map { terrain[Int($0)] }
                        //                        print(pairs, validPairs, corners, values)
                        let sum = values.reduce(0) { a, x in a + x }
                        let average = sum / CGFloat(values.count)
                        let delta = width/CGFloat(numSquares)/smoothness
                        let random = CGFloat.random(in: -delta...delta)
                        let newHeight = average + random
                        //                        print(newHeight)
                        terrain[Int(index)] = newHeight
                    }
                }
            }

            numSquares *= 2
        }

        return terrain
    }

    private func generateMesh(fromTerrain terrain: [CGFloat]) -> SCNGeometry {

        let interval: CGFloat = width / CGFloat(ticks-1)

        let pos = { i, j, height in SCNVector3(i * interval - self.halfWidth,
                                               height,
                                               j * interval - self.halfWidth) }

        var vertices = [SCNVector3]()
        for j in 0..<ticks {
            for i in 0..<ticks {
                let height = terrain[Int(conv(i, j))]
                let vector = pos(CGFloat(i), CGFloat(j), height)
                vertices.append(vector)
            }
        }
        let source = SCNGeometrySource(vertices: vertices)

        var indices = [UInt32]()
        for j in 1..<ticks {
            for i in 1..<ticks {
                indices.append(contentsOf: [conv(i-1, j-1), conv(i-1, j), conv(i, j)])
                indices.append(contentsOf: [conv(i-1, j-1), conv(i, j), conv(i, j-1)])
            }
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        return geometry
    }

    private func makeTriMesh(corners: [CGFloat], depth: Int, radius: CGFloat) -> SCNGeometry {
        var vertices = [SCNVector3]()
        var indices = [UInt32]()

        vertices.append(contentsOf: [
            SCNVector3(x: 0.0, y: corners[0], z: -radius),
            SCNVector3(x: -radius*cos(CGFloat.pi/6.0), y: corners[1], z: radius/2.0),
            SCNVector3(x: radius*cos(CGFloat.pi/6.0), y: corners[2], z: radius/2.0)
        ])

        divide(vertices: &vertices, indices: &indices, depth: depth-1, radius: radius)

        indices.append(contentsOf: [0, 1, 2])

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        return geometry
    }

    private func divide(vertices: inout [SCNVector3], indices: inout [UInt32], depth: Int, radius: CGFloat) {
        vertices.append(contentsOf: [])
    }

    private func generateTriangularTerrain(maxDivisions: Int, corners: [CGFloat]) -> [CGFloat] {
        var result = corners
        result.append(contentsOf: generateTriangularTerrain(division: 1, maxDivisions: maxDivisions, corners: corners))
        return result
    }

    private func generateTriangularTerrain(division: Int, maxDivisions: Int, corners: [CGFloat]) -> [CGFloat] {

        //            0
        //          6   8
        //        3   7   5
        //      9   11  12  14
        //    1   10  4   13   2

        var heights = corners

        if division == maxDivisions {
            return []
        }

        let delta = width/CGFloat(division)/smoothness
        let heightA = displacedMidpoint(a: corners[0], b: corners[1], delta: delta)
        let heightB = displacedMidpoint(a: corners[1], b: corners[2], delta: delta)
        let heightC = displacedMidpoint(a: corners[2], b: corners[0], delta: delta)

        heights.append(contentsOf: [heightA, heightB, heightC])

        heights.append(contentsOf: generateTriangularTerrain(division: division+1,
                                                             maxDivisions: maxDivisions,
                                                             corners: [ corners[0], heightA, heightC ]))

        heights.append(contentsOf: generateTriangularTerrain(division: division+1,
                                                             maxDivisions: maxDivisions,
                                                             corners: [ heightA, corners[1], heightB ]))

        heights.append(contentsOf: generateTriangularTerrain(division: division+1,
                                                             maxDivisions: maxDivisions,
                                                             corners: [ heightC, heightB, corners[2] ]))

        return heights
    }

    private func displacedMidpoint(a: CGFloat, b: CGFloat, delta: CGFloat) -> CGFloat {
        let mean = (a + b) / 2.0
        let random = CGFloat.random(in: -delta...delta)
        let height = mean + random
        return height
    }
}

extension  SCNGeometry{

    /**
     Get the vertices (3d points coordinates) of the geometry.

     - returns: An array of SCNVector3 containing the vertices of the geometry.
     */
    func vertices() -> [SCNVector3]? {

        let sources = self.sources(for: .vertex)

        guard let source  = sources.first else { return nil }

        let stride = source.dataStride / source.bytesPerComponent
        let offset = source.dataOffset / source.bytesPerComponent
        let vectorCount = source.vectorCount

        return source.data.withUnsafeBytes { (buffer : UnsafePointer<Float>) -> [SCNVector3] in

            var result = Array<SCNVector3>()
            for i in 0..<vectorCount {
                let start = i * stride + offset
                let x = buffer[start]
                let y = buffer[start + 1]
                let z = buffer[start + 2]
                result.append(SCNVector3(x, y, z))
            }
            return result
        }
    }
}
