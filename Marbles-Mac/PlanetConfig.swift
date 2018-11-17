struct ColourScale {
    let a: Double
    let b: Double

    init(_ a: Double, _ b: Double) {
        self.a = a
        self.b = b
    }
}

struct RGBColourScale {
    let red: ColourScale
    let green: ColourScale
    let blue: ColourScale
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
    let noise: UnFBM
    let snowNoise: UnFBM

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

        let fractalNoise: UnFBM
        switch noiseType {
        case .gradient:
            let sourceNoise = GradientNoise3D(amplitude: amplitude,
                                              frequency: frequency,
                                              seed: seed)
            fractalNoise = UnFBM(sourceNoise,
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
        self.snowNoise = UnFBM(snowNoiseSource, octaves: 5, persistence: 0.4, lacunarity: 2.5)
    }
}
