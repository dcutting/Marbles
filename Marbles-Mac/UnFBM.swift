public
struct UnFBM
{
    private
    let generators:[GradientNoise3D]

    // UNDOCUMENTED
    public
    func amplitude_scaled(by factor:Double) -> UnFBM
    {
        return UnFBM(generators: self.generators.map{ $0.amplitude_scaled(by: factor) })
    }
    public
    func frequency_scaled(by factor:Double) -> UnFBM
    {
        return UnFBM(generators: self.generators.map{ $0.frequency_scaled(by: factor) })
    }
    public
    func reseeded() -> UnFBM
    {
        return UnFBM(generators: self.generators.map{ $0.reseeded() })
    }

    private
    init(generators:[GradientNoise3D])
    {
        self.generators = generators
    }

    @available(*, unavailable, message: "init(amplitude:frequency:seed:) defaults to octaves = 1, which does not make sense for FBM modules")
    public
    init(amplitude:Double, frequency:Double, seed:Int)
    {
        self.generators = []
    }

    @available(*, unavailable, message: "use init(_:octaves:persistence:lacunarity:) instead")
    public
    init(amplitude:Double, frequency:Double, octaves:Int, persistence:Double = 0.75, lacunarity:Double = 2, seed:Int = 0)
    {
        self.generators  = []
    }

    // UNDOCUMENTED, default was changed from 0.75 to 0.5
    public
    init(_ source:GradientNoise3D, octaves:Int, persistence:Double = 0.5, lacunarity:Double = 2)
    {
        // calculate maximum range
        let range_inverse:Double
        if persistence == 0.5
        {
            range_inverse = Double(1 << (octaves - 1)) / Double(1 << octaves - 1)
        }
        else
        {
            var accumulation:Double = 1,
            contribution:Double = persistence
            for _ in (0 ..< octaves - 1)
            {
                accumulation += contribution
                contribution *= persistence
            }

            range_inverse = 1 / accumulation
        }

        var generators:[GradientNoise3D] = [source.amplitude_scaled(by: range_inverse)]
        generators.reserveCapacity(octaves)
        for i in (0 ..< octaves - 1)
        {
            generators.append(generators[i].amplitude_scaled(by: persistence).frequency_scaled(by: lacunarity).reseeded())
        }

        self.generators  = generators
    }

    public
    func evaluate(_ x:Double, _ y:Double) -> Double
    {
        var Σ:Double = 0
        for generator in self.generators
        {
            Σ += generator.evaluate(x, y) // a .reduce(:{}) is much slower than a simple loop
        }
        return Σ
    }

    public
    func evaluate(_ x:Double, _ y:Double, _ z:Double) -> Double
    {
        var Σ:Double = 0
        for generator in self.generators
        {
            Σ += generator.evaluate(x, y, z)
        }
        return Σ
    }

    public
    func evaluate(_ x:Double, _ y:Double, _ z:Double, _ w:Double) -> Double
    {
        var Σ:Double = 0
        for generator in self.generators
        {
            Σ += generator.evaluate(x, y, z, w)
        }
        return Σ
    }
}
