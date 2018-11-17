public typealias FP = Double

public func unitClamp(_ v: FP) -> FP {
    guard v > 0.0 else { return 0.0 }
    guard v < 1.0 else { return 1.0 }
    return v
}

extension Float {
    func interpolated(to v1: Float, by t: Float) -> Float {
        return (1 - t) * self + t * v1
    }
}

func pow(_ base: UInt32, _ power: UInt32) -> UInt32 {
    var answer: UInt32 = 1
    for _ in 0..<power { answer *= base }
    return answer
}
