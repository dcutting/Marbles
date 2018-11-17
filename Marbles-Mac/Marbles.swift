let earthConfig = PlanetConfig(seed: 12891,
                               radius: 10000.0,
                               frequency: 1.1,
                               amplitude: 0.2,
                               octaves: 12,
                               persistence: 0.48,
                               lacunarity: 2.2,
                               noiseType: .gradient,
                               levels: 0,
                               iciness: 0.5,
                               hasWater: true,
                               ridged: false,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(0x08/0xff, 0x02/0xff),
                                green: ColourScale(0x9d/0xff, 0x18/0xff),
                                blue: ColourScale(0x08/0xff, 0x02/0xff)),
                               waterColourScale: RGBColourScale(
                                red: ColourScale(0x0/0xff, 0x0/0xff),
                                green: ColourScale(0x0/0xff, 0x0/0xff),
                                blue: ColourScale(0x16/0xff, 0xf8/0xff))
)

let vestaConfig = PlanetConfig(seed: 71134,
                               radius: 1000.0,
                               frequency: 0.1,
                               amplitude: 2.5,
                               octaves: 10,
                               persistence: 0.3,
                               lacunarity: 3.1,
                               noiseType: .gradient,
                               levels: 0,
                               iciness: 0.0,
                               hasWater: false,
                               ridged: false,
                               groundColourScale: RGBColourScale(
                                red: ColourScale(0.2, 0.7),
                                green: ColourScale(0.2, 0.7),
                                blue: ColourScale(0.2, 0.7)),
                               waterColourScale: RGBColourScale(
                                red: ColourScale(0x0/0xff, 0x0/0xff),
                                green: ColourScale(0x0/0xff, 0x0/0xff),
                                blue: ColourScale(0x26/0xff, 0xc8/0xff))
)

let marsConfig = PlanetConfig(seed: 729134,
                              radius: 1000.0,
                              frequency: 1.2,
                              amplitude: 0.05,
                              octaves: 12,
                              persistence: 0.46,
                              lacunarity: 2.0,
                              noiseType: .gradient,
                              levels: 0,
                              iciness: 0.2,
                              hasWater: false,
                              ridged: false,
                              groundColourScale: RGBColourScale(
                               red: ColourScale(0.3, 1.0),
                               green: ColourScale(0.05, 0.05),
                               blue: ColourScale(0.05, 0.05))
)
