module Orbits
  class Raster
    getter width : Int32
    getter height : Int32
    getter window : Window
    getter bins : Array(UInt32)

    def initialize(@width : Int32, @height : Int32, @window : Window)
      raise ArgumentError.new("width must be positive") if @width < 1
      raise ArgumentError.new("height must be positive") if @height < 1
      # `add` is called once per generated point; keep window scaling out of
      # that hot loop.
      @xscale = (@width - 1).to_f64 / (@window.xmax - @window.xmin)
      @yscale = (@height - 1).to_f64 / (@window.ymax - @window.ymin)
      @bins = Array(UInt32).new(@width * @height, 0_u32)
    end

    def add(x : Float64, y : Float64) : Nil
      return unless x >= @window.xmin && x <= @window.xmax
      return unless y >= @window.ymin && y <= @window.ymax

      ix = ((x - @window.xmin) * @xscale + 0.5).to_i
      row = ((y - @window.ymin) * @yscale + 0.5).to_i
      return if ix < 0 || ix >= @width || row < 0 || row >= @height

      index = (@height - row - 1) * @width + ix
      @bins[index] &+= 1_u32 unless @bins[index] == UInt32::MAX
    end

    def merge!(other : Raster) : Nil
      unless @width == other.width && @height == other.height && @window == other.window
        raise ArgumentError.new("raster shape mismatch")
      end

      @bins.each_index do |i|
        sum = @bins[i].to_u64 + other.bins[i].to_u64
        @bins[i] = sum > UInt32::MAX ? UInt32::MAX : sum.to_u32
      end
    end

    def transform(xform : Xform) : Bytes
      Xforms.apply(@bins, xform)
    end
  end
end
