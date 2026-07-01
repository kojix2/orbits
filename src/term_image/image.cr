module TermImage
  struct RGBA
    getter width : Int32
    getter height : Int32
    getter pixels : Bytes

    def initialize(@width : Int32, @height : Int32, @pixels : Bytes)
      expected = @width * @height * 4
      raise ArgumentError.new("invalid RGBA byte size") unless @pixels.size == expected
    end

    def to_indexed : Indexed
      indices = Bytes.new(@width * @height)
      palette = StaticArray(UInt32, 256).new(0_u32)
      colors = Hash(UInt32, UInt8).new

      i = 0
      j = 0
      while i < indices.size
        r = @pixels[j].to_u32
        g = @pixels[j + 1].to_u32
        b = @pixels[j + 2].to_u32
        rgb = (r << 16) | (g << 8) | b
        index = colors[rgb]?
        unless index
          return to_rgb332_indexed if colors.size == 256

          index = colors.size.to_u8
          colors[rgb] = index
          palette[index.to_i] = rgb
        end
        indices[i] = index
        i += 1
        j += 4
      end
      Indexed.new(@width, @height, indices, palette)
    end

    private def to_rgb332_indexed : Indexed
      palette = StaticArray(UInt32, 256).new do |i|
        r = ((i >> 5) & 0x7).to_u32 * 255 // 7
        g = ((i >> 2) & 0x7).to_u32 * 255 // 7
        b = (i & 0x3).to_u32 * 255 // 3
        (r << 16) | (g << 8) | b
      end
      indices = Bytes.new(@width * @height)

      i = 0
      j = 0
      while i < indices.size
        r = @pixels[j]
        g = @pixels[j + 1]
        b = @pixels[j + 2]
        indices[i] = ((r & 0xe0) | ((g & 0xe0) >> 3) | (b >> 6)).to_u8
        i += 1
        j += 4
      end
      Indexed.new(@width, @height, indices, palette)
    end
  end

  struct Indexed
    getter width : Int32
    getter height : Int32
    getter indices : Bytes
    getter palette : StaticArray(UInt32, 256)
    # Indexed images are opaque by default; callers that know one palette slot
    # represents background can opt into transparency explicitly.
    getter transparent_index : UInt8?

    def initialize(
      @width : Int32,
      @height : Int32,
      @indices : Bytes,
      @palette : StaticArray(UInt32, 256),
      @transparent_index : UInt8? = nil,
    )
      raise ArgumentError.new("invalid indexed byte size") unless @indices.size == @width * @height
    end

    def to_rgba : RGBA
      pixels = Bytes.new(@width * @height * 4)
      i = 0
      j = 0
      while i < @indices.size
        index = @indices[i]
        rgb = @palette[index.to_i]
        pixels[j] = ((rgb >> 16) & 0xff).to_u8
        pixels[j + 1] = ((rgb >> 8) & 0xff).to_u8
        pixels[j + 2] = (rgb & 0xff).to_u8
        # Preserve round-trips for generic indexed images; only the configured
        # background slot becomes transparent.
        pixels[j + 3] = @transparent_index == index ? 0_u8 : 255_u8
        i += 1
        j += 4
      end
      RGBA.new(@width, @height, pixels)
    end
  end
end
