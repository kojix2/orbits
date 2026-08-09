module Orbits
  # Builds one density raster over a sequence of frames. Unlike Renderer, the
  # orbit and raster survive each call to add_points.
  class ProgressiveRenderer
    getter rendered_points : Int64

    def initialize(@config : Config)
      @raster = Raster.new(@config.width, @config.height, @config.window)
      @orbits = OrbitSeeds.build(@config)
      @next_orbit = 0
      @rendered_points = 0_i64
    end

    def add_points(count : Int64) : Nil
      raise ArgumentError.new("point batch must not be negative") if count < 0
      return if count == 0

      orbit_count = @orbits.size
      base = count // orbit_count
      remainder = (count % orbit_count).to_i

      orbit_count.times do |offset|
        index = (@next_orbit + offset) % orbit_count
        points = base + (offset < remainder ? 1_i64 : 0_i64)
        points.times do
          x, y = @orbits[index].next_point
          @raster.add(x, y)
        end
      end

      @next_orbit = (@next_orbit + remainder) % orbit_count
      @rendered_points += count
    end

    def render : TermImage::Indexed
      TermImage::Indexed.new(
        @config.width,
        @config.height,
        @raster.transform(@config.xform),
        @config.colormap.palette,
        0_u8
      )
    end
  end
end
