{% unless flag?(:execution_context) %}
  {% raise "orbits requires -Dexecution_context" %}
{% end %}

require "./term_image"
require "./orbits/colormap"
require "./orbits/types"
require "./orbits/attractors"
require "./orbits/generator"
require "./orbits/orbit_seeds"
require "./orbits/coefficient_ranges"
require "./orbits/random_params"
require "./orbits/raster"
require "./orbits/xforms"
require "./orbits/renderer"
require "./orbits/progressive_renderer"
require "./orbits/trail_renderer"
require "./orbits/parameter_motion"
require "./orbits/morph_planner"
require "./orbits/termination_monitor"
require "./orbits/animator"
require "./orbits/cli"

module Orbits
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
end
