module Orbits
  # A closed path through each attractor's useful coefficient range. The
  # caller owns time and framing; this module only maps phase to parameters.
  module ParameterMotion
    extend self

    def at(kind : AttractorKind, base : Params, phase : Float64, amount : Float64) : Params
      params = base.dup
      ranges = CoefficientRanges.for(kind)

      case kind
      in .clifford?, .de_jong?
        amplitude = 0.12 * amount
        params.a = bounded(params.a + amplitude * Math.sin(phase), ranges.a)
        params.b = bounded(params.b + amplitude * Math.sin(phase + Math::PI / 2.0), ranges.b)
        params.c = bounded(params.c + amplitude * Math.sin(phase + Math::PI), ranges.c)
        params.d = bounded(params.d + amplitude * Math.sin(phase + 3.0 * Math::PI / 2.0), ranges.d)
      in .ikeda?
        # Increasing u can expand the orbit abruptly. A one-sided closed path
        # retains the user's base value as the upper bound.
        amplitude = 0.015 * amount
        params.a = bounded(params.a - amplitude * (1.0 - Math.cos(phase)) / 2.0, ranges.a)
      in .hopalong?
        amplitude = 0.08 * amount
        params.a = bounded(params.a + amplitude * Math.sin(phase), ranges.a)
        params.b = bounded(params.b + amplitude * Math.sin(phase + 2.0 * Math::PI / 3.0), ranges.b)
        params.c = bounded(params.c + amplitude * Math.sin(phase + 4.0 * Math::PI / 3.0), ranges.c)
      end
      params
    end

    private def bounded(value : Float64, range : Range(Float64, Float64)?) : Float64
      return value unless range

      value.clamp(range.begin, range.end)
    end
  end
end
