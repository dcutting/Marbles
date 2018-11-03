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

let earthConfig = PlanetConfig(seed: 729123134,
                               radius: 10000.0,
                               frequencyFactor: 1.5,
                               mountainHeightFraction: 0.05,
                               hasWater: true,
                               levels: 0,
                               iciness: 0.4,
                               octaves: 12,
                               persistence: 0.52,
                               lacunarity: 2.0,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(0.0, 0.0),
                                green: ColourScale(0.0, 1.0),
                                blue: ColourScale(0.0, 0.0))
)

let vestaConfig = PlanetConfig(seed: 719134,
                               radius: 1000.0,
                               frequencyFactor: 0.5,
                               mountainHeightFraction: 0.3,
                               hasWater: false,
                               levels: 0,
                               iciness: 0.0,
                               octaves: 12,
                               persistence: 0.3,
                               lacunarity: 3.0,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(0.2, 0.7),
                                green: ColourScale(0.2, 0.7),
                                blue: ColourScale(0.2, 0.7))
)

let marsConfig = PlanetConfig(seed: 729134,
                               radius: 1000.0,
                               frequencyFactor: 1.2,
                               mountainHeightFraction: 0.05,
                               hasWater: false,
                               levels: 0,
                               iciness: 0.2,
                               octaves: 12,
                               persistence: 0.46,
                               lacunarity: 2.0,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(0.3, 1.0),
                                green: ColourScale(0.05, 0.05),
                                blue: ColourScale(0.05, 0.05))
)
