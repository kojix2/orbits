module Orbits
  # Creates the nearby starts used by every renderer. Keeping this policy in
  # one place guarantees static, reveal, and trail modes sample identical
  # independent orbits.
  module OrbitSeeds
    extend self

    def build(config : Config) : Array(Orbit)
      Array(Orbit).new(config.orbits) do |index|
        Orbit.new(config.attractor, params(config, index))
      end
    end

    def params(config : Config, index : Int32) : Params
      return config.params if config.orbits == 1

      angle = 2.0 * Math::PI * index.to_f64 / config.orbits
      radius = 1.0e-6
      config.params.with_xy(
        config.params.x0 + Math.cos(angle) * radius,
        config.params.y0 + Math.sin(angle) * radius
      )
    end
  end
end
