struct FractalNoiseConfig {

    var amplitude: Double = 10.0
    var frequency: Double = 1.0
    var seed: Int = 0

    var octaves: Int = 5
    var persistence: Double = 0.5
    var lacunarity: Double = 2.0
}

func makeFractalNoise(config: FractalNoiseConfig) -> Noise {
    let sourceNoise = GradientNoise3D(amplitude: config.amplitude,
                                      frequency: config.frequency,
                                      seed: config.seed)
    return FBM(sourceNoise,
               octaves: config.octaves,
               persistence: config.persistence,
               lacunarity: config.lacunarity)
}
