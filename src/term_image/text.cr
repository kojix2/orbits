module TermImage
  module Text
    extend self

    SHADES = {' ', '░', '▒', '▓', '█'}

    # Keeps ANSI foreground state local to one text render. Repeated colors do
    # not emit redundant control sequences, and no color leaks past a row.
    private class AnsiWriter
      RESET = "\e[0m"
      @color : UInt32?

      def initialize(@output : IO)
        @color = nil
      end

      def write(glyph : Char, color : UInt32?) : Nil
        select_color(color) unless color == @color
        @output << glyph
      end

      def newline : Nil
        reset
        @output << '\n'
      end

      def finish : Nil
        reset
      end

      private def select_color(color : UInt32?) : Nil
        if color
          @output << "\e[38;2;" << ((color >> 16) & 0xff) << ';' << ((color >> 8) & 0xff) << ';' << (color & 0xff) << 'm'
          @color = color
        else
          reset
        end
      end

      private def reset : Nil
        return unless @color

        @output << RESET
        @color = nil
      end
    end

    def write_braille(output : IO, image : Indexed) : Nil
      write_braille_grid(output, image.width, image.height) do |x, y|
        indexed_sample(image, y * image.width + x)
      end
    end

    def write_braille(output : IO, image : RGBA) : Nil
      write_braille_grid(output, image.width, image.height) do |x, y|
        rgba_sample(image, y * image.width + x)
      end
    end

    def write_shades(output : IO, image : Indexed) : Nil
      write_shade_grid(output, image.width, image.height) do |pixel_index|
        indexed_sample(image, pixel_index)
      end
    end

    def write_shades(output : IO, image : RGBA) : Nil
      write_shade_grid(output, image.width, image.height) do |pixel_index|
        rgba_sample(image, pixel_index)
      end
    end

    private def braille_bit(dx : Int32, dy : Int32) : Int32
      case {dx, dy}
      when {0, 0} then 0x01
      when {0, 1} then 0x02
      when {0, 2} then 0x04
      when {0, 3} then 0x40
      when {1, 0} then 0x08
      when {1, 1} then 0x10
      when {1, 2} then 0x20
      when {1, 3} then 0x80
      else             0
      end
    end

    private def write_braille_grid(output : IO, width : Int32, height : Int32,
                                   &sample : Int32, Int32 -> {UInt8, UInt32?}) : Nil
      cell_rows = (height + 3) // 4
      cell_columns = (width + 1) // 2
      writer = AnsiWriter.new(output)

      cell_rows.times do |cell_y|
        writer.newline if cell_y > 0
        cell_columns.times do |cell_x|
          bits = 0
          cell_density = 0_u8
          cell_color : UInt32? = nil
          4.times do |dot_y|
            2.times do |dot_x|
              x = cell_x * 2 + dot_x
              y = cell_y * 4 + dot_y
              next unless x < width && y < height

              density, color = sample.call(x, y)
              next if density.zero?

              bits |= braille_bit(dot_x, dot_y)
              if density > cell_density
                cell_density = density
                cell_color = color
              end
            end
          end
          writer.write((0x2800 + bits).chr, cell_color)
        end
      end
      writer.finish
    end

    private def shade(density : UInt8) : Char
      case density
      when 0...1     then SHADES[0]
      when 1...64    then SHADES[1]
      when 64...128  then SHADES[2]
      when 128...192 then SHADES[3]
      else                SHADES[4]
      end
    end

    private def rgba_density(pixels : Bytes, offset : Int32) : UInt8
      return 0_u8 if pixels[offset + 3] == 0_u8

      r = pixels[offset].to_i
      g = pixels[offset + 1].to_i
      b = pixels[offset + 2].to_i
      ((299 * r + 587 * g + 114 * b) // 1000).clamp(0, 255).to_u8
    end

    private def rgb(pixels : Bytes, offset : Int32) : UInt32
      (pixels[offset].to_u32 << 16) | (pixels[offset + 1].to_u32 << 8) | pixels[offset + 2].to_u32
    end

    private def write_shade_grid(output : IO, width : Int32, height : Int32,
                                 &pixel : Int32 -> {UInt8, UInt32?}) : Nil
      writer = AnsiWriter.new(output)
      height.times do |y|
        writer.newline if y > 0
        width.times do |x|
          density, color = pixel.call(y * width + x)
          writer.write(shade(density), color)
        end
      end
      writer.finish
    end

    private def indexed_sample(image : Indexed, pixel_index : Int32) : {UInt8, UInt32?}
      palette_index = image.indices[pixel_index]
      density = image.transparent_index == palette_index ? 0_u8 : palette_index
      color = density.zero? ? nil : image.palette[palette_index]
      {density, color}
    end

    private def rgba_sample(image : RGBA, pixel_index : Int32) : {UInt8, UInt32?}
      offset = pixel_index * 4
      density = rgba_density(image.pixels, offset)
      color = density.zero? ? nil : rgb(image.pixels, offset)
      {density, color}
    end
  end
end
