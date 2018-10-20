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
        return sqrt(x * x + y * y + z * z)
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

extension FP3 {

    func normalized() -> FP3 {
        let l = length(self)
        if l > 0 {
            return [x / l, y / l, z / l]
        } else {
            return [0.0, 0.0, 0.0]
        }
    }
}

extension float3 {

    func normalized() -> float3 {
        let l = length(self)
        if l > 0 {
            return [x / l, y / l, z / l]
        } else {
            return [0.0, 0.0, 0.0]
        }
    }
}

public func times (left:float3, scalar:Float) -> float3 {
    return [left[0] * scalar, left[1] * scalar, left[2] * scalar]
}
