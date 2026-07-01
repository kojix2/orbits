module Orbits
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
      x = @params.x0
      y = @params.y0
      theta = @params.theta
      current_theta = theta || 0.0

      n.times do
        nx, ny = step(x, y)
        if theta
          factor = Math.cos(current_theta)
          nx *= factor
          ny *= factor
          current_theta += @params.dtheta
        end
        x = nx
        y = ny
        yield x, y
      end
    end

    private def step(x : Float64, y : Float64) : {Float64, Float64}
      @definition.step(x, y, @params)
    end
  end
end
