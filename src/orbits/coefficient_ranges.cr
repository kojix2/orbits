module Orbits
  # Coefficient limits shared by random selection and animated motion. A nil
  # field means the attractor does not use that coefficient.
  record CoefficientRanges,
    a : Range(Float64, Float64)? = nil,
    b : Range(Float64, Float64)? = nil,
    c : Range(Float64, Float64)? = nil,
    d : Range(Float64, Float64)? = nil do
    def self.for(kind : AttractorKind) : self
      case kind
      in .clifford?, .de_jong?
        new(a: -3.0..3.0, b: -3.0..3.0, c: -3.0..3.0, d: -3.0..3.0)
      in .ikeda?
        new(a: 0.6..0.95)
      in .hopalong?
        new(a: -2.0..2.0, b: -2.0..2.0, c: -2.0..2.0)
      end
    end
  end
end
