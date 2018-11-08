import SceneKit

public typealias FP = Double
public typealias FP3 = double3

public func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
}

public func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
}

public func * (left: SCNVector3, scalar: CGFloat) -> SCNVector3 {
    return SCNVector3(left.x * scalar, left.y * scalar, left.z * scalar)
}

public func / (left: SCNVector3, scalar: CGFloat) -> SCNVector3 {
    return SCNVector3(left.x / scalar, left.y / scalar, left.z / scalar)
}

public func unitClamp(_ v: FP) -> FP {
    guard v > 0.0 else { return 0.0 }
    guard v < 1.0 else { return 1.0 }
    return v
}

extension SCNVector3 {

    func length() -> CGFloat {
        return sqrt(lengthSq())
    }

    func lengthSq() -> CGFloat {
        return x * x + y * y + z * z
    }

    func normalized() -> SCNVector3 {
        let l = length()
        if l > 0 {
            return SCNVector3(x / l, y / l, z / l)
        } else {
            return SCNVector3(0.0, 0.0, 0.0)
        }
    }
}

public func times (left:float3, scalar:Float) -> float3 {
    return [left[0] * scalar, left[1] * scalar, left[2] * scalar]
}

func scaledUnitClamp(_ t: FP, v0: FP, v1: FP) -> FP {
    return (1 - t) * v0 + t * v1
}

func pow(_ base: UInt32, _ power: UInt32) -> UInt32 {
    var answer: UInt32 = 1
    for _ in 0..<power { answer *= base }
    return answer
}

func midway(_ a: FP3, _ b: FP3) -> FP3 {

    let abx = (a.x + b.x) / 2.0
    let aby = (a.y + b.y) / 2.0
    let abz = (a.z + b.z) / 2.0

    return [abx, aby, abz]
}

func isIntersecting(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3, width: CGFloat, height: CGFloat) -> Bool {
    let minX = min(a.x, b.x, c.x)
    let maxX = max(a.x, b.x, c.x)
    let minY = min(a.y, b.y, c.y)
    let maxY = max(a.y, b.y, c.y)
    let inset: CGFloat = debug ? 100.0 : 0.0
    let overlapsX = minX <= width - inset && maxX >= inset
    let overlapsY = minY <= height - inset && maxY >= inset
    return overlapsX && overlapsY
}
