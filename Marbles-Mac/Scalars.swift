import SceneKit

public typealias FP = Float

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
