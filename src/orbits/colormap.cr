module Orbits
  enum Colormap
    Ice
    Fire
    Gr8
    Turbo
    Gray

    def self.cli_names : Array(String)
      %w[ice fire gr8 turbo gray]
    end

    def self.parse(value : String) : self
      case value.downcase
      when "ice"                  then Ice
      when "fire"                 then Fire
      when "gr8", "rainbow"       then Gr8
      when "turbo"                then Turbo
      when "gray", "grey", "mono" then Gray
      else
        raise ArgumentError.new("unknown colormap: #{value} (choose from #{cli_names.join(", ")})")
      end
    end

    def cli_name : String
      to_s.downcase
    end

    def palette : StaticArray(UInt32, 256)
      colors = case self
               in .ice?
                 [0x000010_u32, 0x003060_u32, 0x00A0C8_u32, 0xE8FFFF_u32]
               in .fire?
                 [0x000000_u32, 0x4B0055_u32, 0xD82020_u32, 0xFFE066_u32, 0xFFFFFF_u32]
               in .gr8?
                 # Colorful yet monotonic in brightness, so density remains legible.
                 [
                   0x000000_u32, 0x1A0A66_u32, 0x0040E0_u32, 0x00C0E0_u32,
                   0x00D060_u32, 0xC0E000_u32, 0xFFC000_u32, 0xFF3000_u32, 0xFFFFFF_u32,
                 ]
               in .turbo?
                 [
                   0x000000_u32, 0x30123B_u32, 0x4145AB_u32, 0x4675ED_u32, 0x39A2FC_u32,
                   0x1BCFD4_u32, 0x24ECA6_u32, 0x61FC6C_u32, 0xA4FC3B_u32, 0xD1E834_u32,
                   0xF3C63A_u32, 0xFE9B2D_u32, 0xF36315_u32, 0xD93806_u32, 0xB11901_u32,
                 ]
               in .gray?
                 [0x000000_u32, 0xFFFFFF_u32]
               end
      result = gradient(colors)

      # Density 0 always maps to palette index 0; keep empty space pure black
      # so the attractor structure reads as light against a dark field.
      result[0] = 0x000000_u32
      result
    end

    private def gradient(stops : Array(UInt32)) : StaticArray(UInt32, 256)
      StaticArray(UInt32, 256).new do |i|
        t = i / 255.0
        pos = t * (stops.size - 1)
        j = pos.floor.to_i
        j = stops.size - 2 if j >= stops.size - 1
        f = pos - j
        interpolate(stops[j], stops[j + 1], f)
      end
    end

    private def interpolate(a : UInt32, b : UInt32, ratio : Float64) : UInt32
      ar = ((a >> 16) & 0xff).to_i
      ag = ((a >> 8) & 0xff).to_i
      ab = (a & 0xff).to_i
      br = ((b >> 16) & 0xff).to_i
      bg = ((b >> 8) & 0xff).to_i
      bb = (b & 0xff).to_i
      pack_rgb(
        (ar + (br - ar) * ratio).to_i,
        (ag + (bg - ag) * ratio).to_i,
        (ab + (bb - ab) * ratio).to_i
      )
    end

    private def pack_rgb(r : Int32, g : Int32, b : Int32) : UInt32
      ((r.clamp(0, 255).to_u32) << 16) | ((g.clamp(0, 255).to_u32) << 8) | b.clamp(0, 255).to_u32
    end
  end
end
