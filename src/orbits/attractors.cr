module Orbits
  module Attractors
    abstract class Base
      abstract def summary : String
      abstract def formula : Array(String)
      abstract def default_params : Params
      abstract def default_window : Window
      abstract def step(x : Float64, y : Float64, params : Params) : {Float64, Float64}
    end
  end
end

require "./attractors/clifford"
require "./attractors/de_jong"
require "./attractors/ikeda"
require "./attractors/hopalong"

module Orbits
  module Attractors
    extend self

    CLIFFORD = Clifford.new
    DE_JONG  = DeJong.new
    IKEDA    = Ikeda.new
    HOPALONG = Hopalong.new

    def resolve(kind : AttractorKind) : Base
      case kind
      in .clifford?
        CLIFFORD
      in .de_jong?
        DE_JONG
      in .ikeda?
        IKEDA
      in .hopalong?
        HOPALONG
      end
    end
  end
end
