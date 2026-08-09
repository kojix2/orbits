module Orbits
  # Keeps only the newest generated points in the density raster. The fixed
  # ring includes off-screen points as sentinel entries so trail length measures
  # orbit time rather than merely the number of visible samples.
  class TrailRenderer
    HEAD_INDEX_MIN  =    251
    HEAD_INDEX_MAX  =    255
    DENSITY_MAX     = 250_u8
    MIN_HEAD_RADIUS =      3
    MAX_HEAD_RADIUS =     12
    HEAD_SIZE_SCALE =     64
    NO_PIXEL        =     -1
    HEAD_COLORS     = {
      0x4d102f_u32,
      0x8a1f5c_u32,
      0xc72f8a_u32,
      0xff4fbd_u32,
      0xffffff_u32,
    }

    getter active_points : Int64

    def initialize(@config : Config)
      @raster = Raster.new(@config.width, @config.height, @config.window)
      @orbits = OrbitSeeds.build(@config)
      capacity = Math.min(@config.trail_points, @config.points).to_i
      @ring = Array(Int32).new(capacity, NO_PIXEL)
      @ring_head = 0
      @active_points = 0_i64
      @next_orbit = 0
      @latest_pixels = Array(Int32?).new(@orbits.size, nil)
    end

    def add_points(count : Int64) : Nil
      raise ArgumentError.new("point batch must not be negative") if count < 0

      count.times do
        orbit_index = @next_orbit
        orbit = @orbits[orbit_index]
        @next_orbit = (@next_orbit + 1) % @orbits.size
        x, y = orbit.next_point
        pixel = @raster.add(x, y)
        push(pixel)
        @latest_pixels[orbit_index] = pixel
      end
    end

    def render : TermImage::Indexed
      indices = @raster.transform(@config.xform)
      indices.map! { |density| Math.min(density, DENSITY_MAX) }
      @latest_pixels.each { |pixel| mark_head(indices, pixel) if pixel }
      palette = @config.colormap.palette.dup
      HEAD_COLORS.each_with_index { |color, offset| palette[HEAD_INDEX_MIN + offset] = color }
      TermImage::Indexed.new(
        @config.width,
        @config.height,
        indices,
        palette,
        0_u8
      )
    end

    private def push(pixel : Int32?) : Nil
      if @active_points == @ring.size
        expired = @ring[@ring_head]
        @raster.remove(expired) if expired >= 0
      else
        @active_points += 1
      end

      @ring[@ring_head] = pixel || NO_PIXEL
      @ring_head = (@ring_head + 1) % @ring.size
    end

    # A single bright pixel disappears inside a dense attractor. This compact
    # glow marks the current orbit position without altering density history.
    private def mark_head(indices : Bytes, pixel : Int32) : Nil
      center_x = pixel % @config.width
      center_y = pixel // @config.width
      radius = (Math.min(@config.width, @config.height) // HEAD_SIZE_SCALE)
        .clamp(MIN_HEAD_RADIUS, MAX_HEAD_RADIUS)
      fade = (HEAD_INDEX_MAX - HEAD_INDEX_MIN).to_f64 / radius
      (-radius..radius).each do |y_offset|
        (-radius..radius).each do |x_offset|
          distance_squared = x_offset * x_offset + y_offset * y_offset
          next if distance_squared > radius * radius

          x = center_x + x_offset
          y = center_y + y_offset
          next unless x >= 0 && x < @config.width && y >= 0 && y < @config.height

          color_index = (HEAD_INDEX_MAX - Math.sqrt(distance_squared) * fade)
            .round.to_i.clamp(HEAD_INDEX_MIN, HEAD_INDEX_MAX).to_u8
          index = y * @config.width + x
          indices[index] = color_index
        end
      end
    end
  end
end
