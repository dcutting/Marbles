struct FractalNoiseConfig {
    let amplitude: Double
    let frequency: Double
    let seed: Int
    let octaves: Int
    let persistence: Double
    let lacunarity: Double
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
