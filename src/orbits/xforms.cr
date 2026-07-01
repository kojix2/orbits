module Orbits
  module Xforms
    extend self

    def apply(bins : Array(UInt32), xform : Xform) : Bytes
      case xform
      in .boolean?
        boolean(bins)
      in .linear?
        linear(bins)
      in .log?
        log(bins)
      in .log_log?
        log_log(bins)
      in .cubic?
        cubic(bins)
      in .equalized?
        equalized(bins)
      end
    end

    private def boolean(bins : Array(UInt32)) : Bytes
      Bytes.new(bins.size) { |index| bins[index] > 0 ? 255_u8 : 0_u8 }
    end

    private def linear(bins : Array(UInt32)) : Bytes
      normalize(bins) { |density| density }
    end

    private def log(bins : Array(UInt32)) : Bytes
      normalize(bins) { |density| Math.log1p(density) }
    end

    private def log_log(bins : Array(UInt32)) : Bytes
      normalize(bins) { |density| Math.log1p(Math.log1p(density)) }
    end

    private def cubic(bins : Array(UInt32)) : Bytes
      normalize(bins) { |density| density ** 0.3 }
    end

    # All point-wise transforms share the same normalization: subtract the
    # lowest density, transform the remaining span, then stretch it to 0..255.
    private def normalize(bins : Array(UInt32), &transform : Float64 -> Float64) : Bytes
      minimum, maximum = minmax(bins)
      result = Bytes.new(bins.size)
      return result if maximum == minimum

      transformed_maximum = transform.call((maximum - minimum).to_f64)
      factor = 255.0 / transformed_maximum
      bins.each_with_index do |density, index|
        transformed = transform.call((density - minimum).to_f64)
        result[index] = (transformed * factor).to_i.clamp(0, 255).to_u8
      end
      result
    end

    private def equalized(bins : Array(UInt32)) : Bytes
      result = Bytes.new(bins.size)
      return result if bins.empty?

      maximum = bins.max
      # Dense histograms are much faster for normal rendered rasters; fall back
      # for pathological sparse densities to avoid allocating by UInt32 value.
      return equalized_sparse(bins, result) if maximum.to_u64 > bins.size.to_u64

      histogram = Array(Int64).new(maximum.to_i + 1, 0_i64)
      bins.each { |density| histogram[density] += 1_i64 }

      background = 0
      while background < histogram.size && histogram[background] == 0
        background += 1
      end
      return result if background == histogram.size

      foreground_count = bins.size.to_i64 - histogram[background]
      return result if foreground_count <= 0

      lookup = Bytes.new(histogram.size)
      cumulative_count = 0.0
      factor = 255.0 / foreground_count
      (background + 1...histogram.size).each do |density|
        count = histogram[density]
        next if count == 0

        cumulative_count += count
        lookup[density] = (cumulative_count * factor).to_i.clamp(0, 255).to_u8
      end

      bins.each_with_index { |density, index| result[index] = lookup[density] }
      result
    end

    private def equalized_sparse(bins : Array(UInt32), result : Bytes) : Bytes
      # Match GR-style histogram equalization: the lowest populated density
      # is treated as background and the CDF above it is stretched to 0..255.
      histogram = Hash(UInt32, Int64).new(0_i64)
      bins.each { |density| histogram[density] += 1_i64 }

      densities = histogram.keys.sort!
      background = densities.first
      foreground_count = bins.size.to_i64 - histogram[background]
      return result if foreground_count <= 0

      lookup = Hash(UInt32, UInt8).new(0_u8)
      cumulative_count = 0.0
      factor = 255.0 / foreground_count
      densities.each do |density|
        next if density == background

        cumulative_count += histogram[density]
        lookup[density] = (cumulative_count * factor).to_i.clamp(0, 255).to_u8
      end

      bins.each_with_index { |density, index| result[index] = lookup[density] }
      result
    end

    private def minmax(bins : Array(UInt32)) : {UInt32, UInt32}
      return {0_u32, 0_u32} if bins.empty?

      minimum = UInt32::MAX
      maximum = 0_u32
      bins.each do |density|
        maximum = density if density > maximum
        minimum = density if density < minimum
      end
      {minimum, maximum}
    end
  end
end
