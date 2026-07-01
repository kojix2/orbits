module Orbits
  module Attractors
    class DeJong < Base
      def summary : String
        "De Jong attractor"
      end

      def formula : Array(String)
        [
          "xₙ₊₁ = sin(a·yₙ) − cos(b·xₙ)",
          "yₙ₊₁ = sin(c·xₙ) − cos(d·yₙ)",
        ]
      end

      def default_params : Params
        Params.new(1.4, -2.3, 2.4, -2.1)
      end

      def default_window : Window
        Window.default
      end

      def step(x : Float64, y : Float64, params : Params) : {Float64, Float64}
        {
          Math.sin(params.a * y) - Math.cos(params.b * x),
          Math.sin(params.c * x) - Math.cos(params.d * y),
        }
      end
    end
  end
end
