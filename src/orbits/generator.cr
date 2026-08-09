module Orbits
  # A stateful walk through one attractor orbit. Keeping the current point here
  # lets interactive renderers advance the same orbit in small batches without
  # restarting it for every frame.
  class Orbit
    def initialize(kind : AttractorKind, params : Params)
      initialize(Attractors.resolve(kind), params)
    end

    def initialize(@definition : Attractors::Base, @params : Params)
      @x = @params.x0
      @y = @params.y0
      @theta = @params.theta || 0.0
      @theta_enabled = !@params.theta.nil?
    end

    def next_point : {Float64, Float64}
      nx, ny = @definition.step(@x, @y, @params)
      if @theta_enabled
        factor = Math.cos(@theta)
        nx *= factor
        ny *= factor
        @theta += @params.dtheta
      end
      @x = nx
      @y = ny
      {@x, @y}
    end
  end

  class Generator
    def initialize(kind : AttractorKind, @params : Params)
      @definition = Attractors.resolve(kind)
    end

    def initialize(@definition : Attractors::Base, @params : Params)
    end

    def initialize(@params : Params)
      initialize(AttractorKind::Clifford, @params)
    end

    def each_point(n : Int64, &)
      orbit = Orbit.new(@definition, @params)
      n.times do
        x, y = orbit.next_point
        yield x, y
      end
    end
  end
end
