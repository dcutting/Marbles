import GameKit

class PerlinMesh {

    private let n: Int

    // Precomputed (or otherwise) gradient vectors at each grid node
    private let gradient: [[[Float]]]

    init(n: Int, seed: UInt64) {
        self.n = n
        var gradient = [[[Float]]](repeating: [[Float]](repeating: [Float](repeating: 0.0, count: 2), count: n), count: n)

        let rs = GKMersenneTwisterRandomSource()
        rs.seed = seed

        let rd = GKRandomDistribution(randomSource: rs, lowestValue: 0, highestValue: 1)

        for j in 0..<n {
            for i in 0..<n {
                gradient[j][i][0] = rd.nextUniform()
                gradient[j][i][1] = rd.nextUniform()
            }
        }

        self.gradient = gradient
    }

    // Function to linearly interpolate between a0 and a1
    // Weight w should be in the range [0.0, 1.0]
    private func lerp(_ a0: Float, _ a1: Float, _ w: Float) -> Float {
        return (1.0 - w)*a0 + w*a1
        // as an alternative, this slightly faster equivalent formula can be used:
        // return a0 + w*(a1 - a0);
    }

    // Computes the dot product of the distance and gradient vectors.
    private func dotGridGradient(_ ix: Int, _ iy: Int, _ x: Float, _ y: Float) -> Float {

        // Compute the distance vector
        let dx = x - Float(ix)
        let dy = y - Float(iy)

        // Compute the dot-product
        return (dx*gradient[iy][ix][0] + dy*gradient[iy][ix][1])
    }

    // Compute Perlin noise at coordinates x, y
    func noise(x: Float, y: Float) -> Float {

        // Determine grid cell coordinates
        let x0 = Int(x) % n
        let x1 = x0 + 1
        let y0 = Int(y) % n
        let y1 = y0 + 1

//        print(x, y, x0, x1, y0, y1)

        // Determine interpolation weights
        // Could also use higher order polynomial/s-curve here
        let sx = x - Float(x0)
        let sy = y - Float(y0)

        // Interpolate between grid point gradients
        let na0, na1, nb0, nb1, ix0, ix1, value: Float
        na0 = dotGridGradient(x0, y0, x, y)
        na1 = dotGridGradient(x1, y0, x, y)
        ix0 = lerp(na0, na1, sx)
        nb0 = dotGridGradient(x0, y1, x, y)
        nb1 = dotGridGradient(x1, y1, x, y)
        ix1 = lerp(nb0, nb1, sx)
        value = lerp(ix0, ix1, sy)

        return value
    }
}
