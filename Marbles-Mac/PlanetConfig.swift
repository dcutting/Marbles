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
}

enum NoiseType {
    case gradient
//    case cellular
}

struct PlanetConfig {

    let radius: Double
    let diameterSq: Double
    let levels: Int
    let iciness: Double
    let hasWater: Bool
    let ridged: Bool
    let groundColourScale: RGBColourScale
    let waterColourScale: RGBColourScale

    let minimumRadius: Double
    let mountainHeight: Double
    let frequency: Double
    let amplitude: Double
    let oceanDepth: Double
    let noise: FBMGradient3D
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
         waterColourScale: RGBColourScale) {

        self.radius = radius
        self.diameterSq = (radius * 2) * (radius * 2)
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

        self.minimumRadius = hasWater ? (radius - oceanDepth) : (radius - mountainHeight)

        let fractalNoise: FBMGradient3D
        switch noiseType {
        case .gradient:
            let sourceNoise = GradientNoise3D(amplitude: amplitude,
                                              frequency: frequency,
                                              seed: seed)
            fractalNoise = FBMGradient3D(sourceNoise,
                               octaves: octaves,
                               persistence: persistence,
                               lacunarity: lacunarity)
//        case .cellular:
//            let sourceNoise = CellNoise3D(amplitude: amplitude,
//                                          frequency: frequency,
//                                          seed: seed)
//            fractalNoise = FBM(sourceNoise,
//                               octaves: octaves,
//                               persistence: persistence,
//                               lacunarity: lacunarity)
        }

//        if ridged {
//            self.noise = RidgedNoise(noise: fractalNoise, amplitude: amplitude)
//        } else {
            self.noise = fractalNoise
//        }

        // TODO: make snow noise depend on planet radius, etc.
        let snowNoiseSource = GradientNoise3D(amplitude: 800, frequency: 0.001, seed: seed+1)
        self.snowNoise = FBMGradient3D(snowNoiseSource, octaves: 5, persistence: 0.4, lacunarity: 2.5)
    }
}
