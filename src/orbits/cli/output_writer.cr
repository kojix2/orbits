module Orbits
  module CLI
    # Selects a file encoding without involving terminal detection. Explicit
    # text protocols take precedence; a .six suffix otherwise selects SIXEL.
    private class OutputWriter
      def initialize(@path : String, @image : TermImage::Indexed,
                     @protocol : TermImage::Protocol)
      end

      def write : Nil
        if @protocol.braille?
          write_text { |output| TermImage::Text.write_braille(output, @image) }
        elsif @protocol.shades?
          write_text { |output| TermImage::Text.write_shades(output, @image) }
        elsif @path.ends_with?(".six") || @protocol.sixel?
          File.open(@path, "w") { |output| TermImage::Sixel.write(output, @image) }
        else
          File.write(@path, TermImage::PNG.encode(@image.to_rgba))
        end
      end

      private def write_text(& : IO ->) : Nil
        File.open(@path, "w") do |output|
          yield output
          output << '\n'
        end
      end
    end
  end
end
