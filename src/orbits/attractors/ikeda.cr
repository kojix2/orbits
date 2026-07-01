module Orbits
  module Attractors
    class Ikeda < Base
      def summary : String
        "Ikeda attractor"
      end

      def formula : Array(String)
        [
          "tₙ   = 0.4 − 6 / (1 + xₙ² + yₙ²)",
          "xₙ₊₁ = 1 + u·(xₙ·cos tₙ − yₙ·sin tₙ)",
          "yₙ₊₁ = u·(xₙ·sin tₙ + yₙ·cos tₙ)",
        ]
      end

      def default_params : Params
        Params.new(0.9, 0.0, 0.0, 0.0, x0: 0.1, y0: 0.1)
      end

      def default_window : Window
        Window.new(-0.5, 1.7, -2.2, 1.0)
      end

      def step(x : Float64, y : Float64, params : Params) : {Float64, Float64}
        t = 0.4 - 6.0 / (1.0 + x * x + y * y)
        u = params.a
        {
          1.0 + u * (x * Math.cos(t) - y * Math.sin(t)),
          u * (x * Math.sin(t) + y * Math.cos(t)),
        }
      end
    end
  end
end
