import Foundation

struct ColourScale {
    let a: Float
    let b: Float

    init(_ a: Float, _ b: Float) {
        self.a = a
        self.b = b
    }

    func interpolated(by t: Float) -> Float {
        return a.interpolated(to: b, by: t)
    }

    static var all = ColourScale(0.0, 1.0)
}

struct RGBColourScale {
    let red: ColourScale
    let green: ColourScale
    let blue: ColourScale

    func interpolated(by t: Float) -> Patch.Colour {
        return Patch.Colour(red.interpolated(by: t),
                            green.interpolated(by: t),
                            blue.interpolated(by: t))
    }

    static var grey = RGBColourScale(red: .all, green: .all, blue: .all)
}

enum NoiseType {
    case gradient
    case cellular
}

struct PlanetConfig {

    let radius: FP
    let levels: Int
    let iciness: FP
    let hasWater: Bool
    let ridged: Bool
    let groundColourScale: RGBColourScale
    let waterColourScale: RGBColourScale

    let diameter: FP
    let diameterSq: FP
    let radiusSq: FP
    let radiusSqrt: FP
    let minimumRadius: FP
    let mountainHeight: FP
    let frequency: FP
    let amplitude: FP
    let oceanDepth: FP
    let noise: Noise
    let snowNoise: FBMGradient3D

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
         groundColourScale: RGBColourScale,
         waterColourScale: RGBColourScale = .grey) {

        self.radius = radius
        self.frequency = unscaledFrequency / radius
        self.amplitude = radius * unscaledAmplitude
        self.levels = levels
        self.iciness = iciness
        self.hasWater = hasWater
        self.ridged = ridged
        self.groundColourScale = groundColourScale
        self.waterColourScale = waterColourScale

        self.mountainHeight = amplitude / 2.0
        self.oceanDepth = amplitude / 20.0

        self.diameter = radius * 2
        self.diameterSq = diameter * diameter
        self.radiusSq = radius * radius
        self.radiusSqrt = sqrt(radius)
        self.minimumRadius = hasWater ? (radius - oceanDepth) : (radius - mountainHeight)

        let fractalNoise: Noise
        switch noiseType {
        case .gradient:
            let sourceNoise = GradientNoise3D(amplitude: amplitude,
                                              frequency: frequency,
                                              seed: seed)
            fractalNoise = FBMGradient3D(sourceNoise,
                                         octaves: octaves,
                                         persistence: persistence,
                                         lacunarity: lacunarity)
        case .cellular:
            let sourceNoise = CellNoise3D(amplitude: amplitude,
                                          frequency: frequency,
                                          seed: seed)
            fractalNoise = FBMCellular3D(sourceNoise,
                                         octaves: octaves,
                                         persistence: persistence,
                                         lacunarity: lacunarity)
        }

//        if ridged {
//            self.noise = RidgedNoise(noise: fractalNoise, amplitude: amplitude)
//        } else {
            self.noise = fractalNoise
//        }

        let snowNoiseSource = GradientNoise3D(amplitude: amplitude / 5, frequency: frequency * 20, seed: seed+1)
        self.snowNoise = FBMGradient3D(snowNoiseSource, octaves: 5, persistence: 0.5, lacunarity: 2.0)
    }
}
