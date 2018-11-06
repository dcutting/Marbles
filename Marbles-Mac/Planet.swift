struct ColourScale {
    let min: Double
    let max: Double
}

struct RGBColourScale {
    let red: ColourScale
    let green: ColourScale
    let blue: ColourScale
}

enum NoiseType {
    case gradient
    case cellular
}

struct PlanetConfig {

    let radius: Double
    let levels: Int
    let iciness: Double
    let hasWater: Bool
    let ridged: Bool
    let groundColourScale: RGBColourScale

    let mountainHeight: Double
    let frequency: Double
    let amplitude: Double
    let oceanDepth: Double
    let noise: Noise

    init(seed: Int,
         radius: Double,
         frequency unscaledFrequency: Double,
         amplitude unscaledAmplitude: Double,
         octaves: Int,
         persistence: Double,
         lacunarity: Double,
         noiseType: NoiseType,
         levels: Int,
         iciness: Double,
         hasWater: Bool,
         ridged: Bool,
         groundColourScale: RGBColourScale) {

        self.radius = radius
        self.frequency = unscaledFrequency / radius
        self.amplitude = radius * unscaledAmplitude
        self.levels = levels
        self.iciness = iciness
        self.hasWater = hasWater
        self.ridged = ridged
        self.groundColourScale = groundColourScale

        self.mountainHeight = amplitude / 2.0
        self.oceanDepth = amplitude / 20.0

        let fractalNoise: Noise
        switch noiseType {
        case .gradient:
            let sourceNoise = GradientNoise3D(amplitude: amplitude,
                                              frequency: frequency,
                                              seed: seed)
            fractalNoise = FBM(sourceNoise,
                               octaves: octaves,
                               persistence: persistence,
                               lacunarity: lacunarity)
        case .cellular:
            let sourceNoise = CellNoise3D(amplitude: amplitude,
                                          frequency: frequency,
                                          seed: seed)
            fractalNoise = FBM(sourceNoise,
                               octaves: octaves,
                               persistence: persistence,
                               lacunarity: lacunarity)
        }

        if ridged {
            self.noise = RidgedNoise(noise: fractalNoise, amplitude: amplitude)
        } else {
            self.noise = fractalNoise
        }
    }
}

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

func makePatchCalculator(planet: PlanetConfig) -> PatchCalculator {
    return PatchCalculator(config: planet)
}

let phi: FP = 1.6180339887498948482

let positions: [FP3] = [
    [1, phi, 0],
    [-1, phi, 0],
    [1, -phi, 0],
    [-1, -phi, 0],
    [0, 1, phi],
    [0, -1, phi],
    [0, 1, -phi],
    [0, -1, -phi],
    [phi, 0, 1],
    [-phi, 0, 1],
    [phi, 0, -1],
    [-phi, 0, -1]
]

let faces: [[UInt32]] = [
    [4, 5, 8],
    [4, 9, 5],
    [4, 8, 0],
    [4, 1, 9],
    [0, 1, 4],
    [1, 11, 9],
    [9, 11, 3],
    [1, 6, 11],
    [0, 6, 1],
    [5, 9, 3],
    [10, 0, 8],
    [10, 6, 0],
    [11, 7, 3],
    [5, 2, 8],
    [10, 8, 2],
    [10, 2, 7],
    [6, 7, 11],
    [6, 10, 7],
    [5, 3, 2],
    [2, 3, 7]
]

let earthConfig = PlanetConfig(seed: 72934,
                               radius: 10000.0,
                               frequency: 1.5,
                               amplitude: 0.1,
                               octaves: 20,
                               persistence: 0.5,
                               lacunarity: 2.0,
                               noiseType: .gradient,
                               levels: 0,
                               iciness: 0.3,
                               hasWater: true,
                               ridged: false,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(min: 0.0, max: 0.0),
                                green: ColourScale(min: 0.0, max: 1.0),
                                blue: ColourScale(min: 0.0, max: 0.0))
)

let ridgeConfig = PlanetConfig(seed: 729123134,
                               radius: 10000.0,
                               frequency: 1.5,
                               amplitude: 0.1,
                               octaves: 12,
                               persistence: 0.5,
                               lacunarity: 2.0,
                               noiseType: .gradient,
                               levels: 0,
                               iciness: 0.3,
                               hasWater: true,
                               ridged: true,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(min: 0.0, max: 0.0),
                                green: ColourScale(min: 0.0, max: 1.0),
                                blue: ColourScale(min: 0.0, max: 0.0))
)

let vestaConfig = PlanetConfig(seed: 719134,
                               radius: 1000.0,
                               frequency: 2.0,
                               amplitude: 0.6,
                               octaves: 12,
                               persistence: 0.3,
                               lacunarity: 3.0,
                               noiseType: .cellular,
                               levels: 0,
                               iciness: 0.0,
                               hasWater: false,
                               ridged: false,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(min: 0.2, max: 0.7),
                                green: ColourScale(min: 0.2, max: 0.7),
                                blue: ColourScale(min: 0.2, max: 0.7))
)

//let marsConfig = PlanetConfig(seed: 729134,
//                               radius: 1000.0,
//                               frequencyFactor: 1.2,
//                               mountainHeightFraction: 0.05,
//                               hasWater: false,
//                               levels: 0,
//                               iciness: 0.2,
//                               octaves: 12,
//                               persistence: 0.46,
//                               lacunarity: 2.0,
//                               ridged: false,
//                               groundColourScale: RGBColourScale(
//                                red: ColourScale(0.3, 1.0),
//                                green: ColourScale(0.05, 0.05),
//                                blue: ColourScale(0.05, 0.05))
//)
