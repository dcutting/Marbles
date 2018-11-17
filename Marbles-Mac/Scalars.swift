import SceneKit

public typealias FP = Double

extension FP {
    func unitClamped() -> FP {
        return simd_clamp(self, 0.0, 1.0)
    }
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
