module Orbits
  module Attractors
    class Clifford < Base
      def summary : String
        "Clifford attractor"
      end

      def formula : Array(String)
        [
          "xₙ₊₁ = sin(a·yₙ) + c·cos(a·xₙ)",
          "yₙ₊₁ = sin(b·xₙ) + d·cos(b·yₙ)",
        ]
      end

      def default_params : Params
        Params.new(-1.3, -1.3, -1.8, -1.9, theta: 0.007, dtheta: 0.007)
      end

      def default_window : Window
        Window.default
      end

      def step(x : Float64, y : Float64, params : Params) : {Float64, Float64}
        {
          Math.sin(params.a * y) + params.c * Math.cos(params.a * x),
          Math.sin(params.b * x) + params.d * Math.cos(params.b * y),
        }
      end
    end
  end
end
