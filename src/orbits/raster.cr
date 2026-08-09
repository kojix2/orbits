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
      @overflow = Hash(Int32, UInt64).new
    end

    def add(x : Float64, y : Float64) : Int32?
      return unless index = index_for(x, y)
      if @bins[index] == UInt32::MAX
        overflow = @overflow[index]? || 0_u64
        @overflow[index] = overflow + 1_u64 unless overflow == UInt64::MAX
      else
        @bins[index] &+= 1_u32
      end
      index
    end

    def remove(index : Int32) : Nil
      raise ArgumentError.new("pixel index out of bounds") unless index >= 0 && index < @bins.size
      if overflow = @overflow[index]?
        if overflow == 1
          @overflow.delete(index)
        else
          @overflow[index] = overflow - 1_u64
        end
      else
        @bins[index] -= 1_u32 unless @bins[index].zero?
      end
    end

    def merge!(other : Raster) : Nil
      unless @width == other.width && @height == other.height && @window == other.window
        raise ArgumentError.new("raster shape mismatch")
      end

      @bins.each_index do |i|
        sum = @bins[i].to_u128 + overflow_at(i).to_u128 +
              other.bins[i].to_u128 + other.overflow_at(i).to_u128
        if sum > UInt32::MAX
          @bins[i] = UInt32::MAX
          excess = sum - UInt32::MAX
          @overflow[i] = Math.min(excess, UInt64::MAX.to_u128).to_u64
        else
          @bins[i] = sum.to_u32
          @overflow.delete(i)
        end
      end
    end

    def transform(xform : Xform) : Bytes
      Xforms.apply(@bins, xform)
    end

    private def index_for(x : Float64, y : Float64) : Int32?
      return unless x >= @window.xmin && x <= @window.xmax
      return unless y >= @window.ymin && y <= @window.ymax

      ix = ((x - @window.xmin) * @xscale + 0.5).to_i
      row = ((y - @window.ymin) * @yscale + 0.5).to_i
      return if ix < 0 || ix >= @width || row < 0 || row >= @height

      (@height - row - 1) * @width + ix
    end

    protected def overflow_at(index : Int32) : UInt64
      @overflow[index]? || 0_u64
    end
  end
end
