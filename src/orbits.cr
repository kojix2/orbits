require "./term_image"
require "./orbits/colormap"
require "./orbits/types"
require "./orbits/attractors"
require "./orbits/generator"
require "./orbits/random_params"
require "./orbits/raster"
require "./orbits/xforms"
require "./orbits/renderer"
require "./orbits/cli"

module Orbits
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
end
