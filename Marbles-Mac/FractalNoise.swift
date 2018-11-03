struct RGBColourScale {
    let red: ColourScale
    let green: ColourScale
    let blue: ColourScale
}

struct ColourScale {
    let min: Double
    let max: Double

    init(_ min: Double, _ max: Double) {
        self.min = min
        self.max = max
    }
}

struct PlanetConfig {
    let seed: Int
    let radius: Double
    let frequencyFactor: Double
    let mountainHeightFraction: Double
    let hasWater: Bool
    let levels: Int
    let iciness: Double
    let octaves: Int
    let persistence: Double
    let lacunarity: Double
    let groundColourScale: RGBColourScale

    let diameter: Double
    let mountainHeight: Double
    let frequency: Double
    let amplitude: Double
    let oceanDepth: Double
    let noise: Noise

    init(seed: Int, radius: Double, frequencyFactor: Double, mountainHeightFraction: Double, hasWater: Bool, levels: Int, iciness: Double, octaves: Int, persistence: Double, lacunarity: Double, groundColourScale: RGBColourScale) {
        self.seed = seed
        self.radius = radius
        self.frequencyFactor = frequencyFactor
        self.mountainHeightFraction = mountainHeightFraction
        self.hasWater = hasWater
        self.levels = levels
        self.iciness = iciness
        self.octaves = octaves
        self.persistence = persistence
        self.lacunarity = lacunarity
        self.groundColourScale = groundColourScale

        self.diameter = radius * 2
        self.mountainHeight = radius * mountainHeightFraction
        self.frequency = frequencyFactor / radius
        self.amplitude = radius * mountainHeightFraction * 2.0
        self.oceanDepth = amplitude / 20.0

        let sourceNoise = GradientNoise3D(amplitude: amplitude,
                                          frequency: frequency,
                                          seed: seed)
        self.noise = FBM(sourceNoise,
                         octaves: octaves,
                         persistence: persistence,
                         lacunarity: lacunarity)
    }
}

func makePatchCalculator(planet: PlanetConfig) -> PatchCalculator {
    return PatchCalculator(config: planet)
}
