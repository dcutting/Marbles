public class RidgedNoise: Noise {

    private let noise: Noise
    private let amplitude: Double

    public func amplitude_scaled(by factor: Double) -> Self {
        fatalError("unsupported")
    }

    public func frequency_scaled(by factor: Double) -> Self {
        fatalError("unsupported")
    }

    public func reseeded() -> Self {
        fatalError("unsupported")
    }

    init(noise: Noise, amplitude: Double) {
        self.noise = noise.amplitude_scaled(by: 2.0).frequency_scaled(by: 0.25)
        self.amplitude = amplitude
    }

    public func evaluate(_ x: Double, _ y: Double) -> Double {
        return applyRidge(self.noise.evaluate(x, y))
    }

    public func evaluate(_ x: Double, _ y: Double, _ z: Double) -> Double {
        return applyRidge(self.noise.evaluate(x, y, z))
    }

    public func evaluate(_ x: Double, _ y: Double, _ z: Double, _ w: Double) -> Double {
        return applyRidge(self.noise.evaluate(x, y, z, w))
    }

    private func applyRidge(_ v: Double) -> Double {
        return abs(v) * -1.0 + self.amplitude / 2.0
    }
}
