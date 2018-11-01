import SceneKit

typealias FP = Double
typealias FP3 = double3

public func + (left:SCNVector3, right:SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
}

public func - (left:SCNVector3, right:SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
}

public func * (left:SCNVector3, scalar:CGFloat) -> SCNVector3 {
    return SCNVector3(left.x * scalar, left.y * scalar, left.z * scalar)
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

func scaledUnitClamp(_ v: FP, min: FP, max: FP = 1.0) -> FP {
    return v * (max-min) + min
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
