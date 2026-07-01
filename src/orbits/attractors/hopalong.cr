module Orbits
  module Attractors
    class Hopalong < Base
      def summary : String
        "Hopalong attractor"
      end

      def formula : Array(String)
        [
          "xₙ₊₁ = yₙ − sgn(xₙ)·√|b·xₙ − c|",
          "yₙ₊₁ = a − xₙ",
        ]
      end

      def default_params : Params
        Params.new(0.4, 1.0, 0.0, 0.0)
      end

      def default_window : Window
        Window.default
      end

      def step(x : Float64, y : Float64, params : Params) : {Float64, Float64}
        root = Math.sqrt((params.b * x - params.c).abs)
        signed_root = x < 0 ? -root : root
        {
          y - signed_root,
          params.a - x,
        }
      end
    end
  end
end
