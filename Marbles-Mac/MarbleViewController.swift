import AppKit
import SceneKit

let debug = false

class MarbleViewController: NSViewController, PlanetDelegate {

    let patchBuffer = PatchBuffer()
    lazy var earth = Planet(name: "Earth", config: earthConfig, patchBuffer: patchBuffer)
    lazy var moon = Planet(name: "Moon", config: vestaConfig, patchBuffer: patchBuffer)
    lazy var planets = [earth, moon]
    let updateInterval = 0.1
    let sunDayDuration: FP = 1000
    let moonDayDuration: FP = 30
    let moonMonthDuration: FP = 300
    let flyingSpeed: FP = 200.0
    var wireframe: Bool = false {
        didSet {
            updateDebugOptions()
        }
    }

    var screenWidth: FP = 0.0
    var halfScreenWidthSq: FP = 0.0
    var screenHeight: FP = 0.0
    var screenCenter = Patch.Vertex()
    let scene = SCNScene()
    let terrainQueue = DispatchQueue(label: "terrain", qos: .userInteractive, attributes: .concurrent)

    var scnView: SCNView {
        return view as! SCNView
    }

    private func updateDebugOptions() {
        if wireframe {
            scnView.debugOptions.insert(.renderAsWireframe)
        } else {
            scnView.debugOptions.remove(.renderAsWireframe)
        }
        planets.forEach { $0.wireframe = wireframe }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        planets.forEach { $0.delegate = self }

        updateBounds()
        updateDebugOptions()

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
        sunParent.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: sunDayDuration)))
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
        cameraNode.position = SCNVector3(x: 5000.0, y: 5000.0, z: 22000.0)
        cameraNode.camera = camera
        cameraNode.look(at: SCNVector3())
        scene.rootNode.addChildNode(cameraNode)

        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.defaultCameraController.interactionMode = .fly

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

    private func altitude(from planet: Planet) -> FP {
        let d = (cameraPosition - Patch.Vertex(planet.terrainNode.position)).length() - planet.config.radius
        if d < 0.0 { return 0.0 }
        return d
    }

    private func adaptFlyingSpeed() {
        let altitudes = planets.map { altitude(from: $0) }
        let closest = altitudes.sorted().first!
        let newVelocity = max(sqrt(closest * flyingSpeed), 1.0)
        self.scnView.cameraControlConfiguration.flyModeVelocity = CGFloat(newVelocity)
    }

    private func makeTerrain() {

        let earthNode = earth.makeTerrain()
        scene.rootNode.addChildNode(earthNode)

        let moonNode = moon.makeTerrain()
        moonNode.position = SCNVector3(x: 30000, y: 0, z: 0)
        moonNode.runAction(.repeatForever(.rotateBy(x: 10, y: 20, z: -40, duration: moonDayDuration)))
        let moonFrame = SCNNode()
        moonFrame.addChildNode(moonNode)
        moonFrame.runAction(.repeatForever(.rotateBy(x: 0, y: 20, z: 0, duration: moonMonthDuration)))
        scene.rootNode.addChildNode(moonFrame)

        self.refreshGeometry()
    }

    private func refreshGeometry() {
        self.terrainQueue.asyncAfter(deadline: .now() + self.updateInterval) {
            self.patchBuffer.clearBuffer()
            for planet in self.planets {
                planet.refreshGeometry()
                planet.updateNode()
            }
            DispatchQueue.main.sync {
                self.adaptFlyingSpeed()
            }
            self.refreshGeometry()
        }
    }

    func project(point: SCNVector3) -> Patch.Vertex {
        return Patch.Vertex(scnView.projectPoint(point))
    }

    func isIntersectingScreen(triangle: Triangle) -> Bool {
        let inset: FP = debug ? 100.0 : 0.0
        return triangle.isIntersecting(width: screenWidth, height: screenHeight, inset: inset)
    }

    func distanceSqFromCamera(triangle: Triangle) -> FP {
        return triangle.distanceSq(from: cameraPosition)
    }

    func distanceSqFromScreenCenter(triangle: Triangle) -> FP {
        return (triangle.centroid - screenCenter).lengthSq() / halfScreenWidthSq
    }
}
