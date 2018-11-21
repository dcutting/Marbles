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
    let frequency: FP
    let amplitude: FP
    let octaves: Int
    let persistence: FP
    let lacunarity: FP
    let noiseType: NoiseType
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
    let oceanDepth: FP

    init(radius: FP,
         frequency unscaledFrequency: FP,
         amplitude unscaledAmplitude: FP,
         octaves: Int,
         persistence: FP,
         lacunarity: FP,
         noiseType: NoiseType,
         levels: Int,
         iciness: FP,
         hasWater: Bool,
         ridged: Bool,
         groundColourScale: RGBColourScale,
         waterColourScale: RGBColourScale = .grey) {

        self.radius = radius
        self.frequency = unscaledFrequency / radius
        self.amplitude = radius * unscaledAmplitude
        self.octaves = octaves
        self.persistence = persistence
        self.lacunarity = lacunarity
        self.noiseType = noiseType
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
    }
}
