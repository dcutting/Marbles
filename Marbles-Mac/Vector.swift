import SceneKit

public func + (left:SCNVector3, right:SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
}
/*
public func += ( left:inout SCNVector3, right:SCNVector3) {
    left = left + right
}

public func - (left:SCNVector3, right:SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
}

public func -= ( left:inout SCNVector3, right:SCNVector3) {
    left = left - right
}

public func * (left:SCNVector3, right:SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x * right.x, left.y * right.y, left.z * right.z)
}

public func *= ( left:inout SCNVector3, right:SCNVector3) {
    left = left * right
}
*/
public func * (left:SCNVector3, scalar:CGFloat) -> SCNVector3 {
    return SCNVector3(left.x * scalar, left.y * scalar, left.z * scalar)
}
/*
public func / (left:SCNVector3, scalar:SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x / scalar.x, left.y / scalar.y, left.z / scalar.z)
}

public func /= ( left:inout SCNVector3, scalar: Float) {
    left = left / SCNVector3(scalar, scalar, scalar)
}

public func /= ( left:inout SCNVector3, scalar: SCNVector3) {
    left = left / scalar
}
*/

extension SCNVector3 {
//    static func getMidpoint(v1:SCNVector3, v2:SCNVector3) -> SCNVector3 {
//        return SCNVector3((v1.x + v2.x) * 0.5, (v1.y + v2.y) * 0.5, (v1.z + v2.z) * 0.5)
//    }
//
//    static func zero() -> SCNVector3 {
//        return SCNVector3(0, 0, 0)
//    }

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

//    func string() -> String {
//        return "\(x), \(y), \(z)"
//    }
}
