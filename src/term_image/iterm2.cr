module TermImage
  module Iterm2
    extend self

    CHUNK_SIZE = 900_000

    def write(output : IO, image : RGBA, height_cells : Int32? = nil) : Nil
      png = PNG.encode(image)
      b64 = Base64.strict_encode(png)
      height = height_cells || 0
      height_arg = height > 0 ? "height=#{height};" : ""

      output << "\e]1337;MultipartFile=inline=1;#{height_arg}size=#{png.size};preserveAspectRatio=1\a"
      offset = 0
      while offset < b64.bytesize
        count = Math.min(CHUNK_SIZE, b64.bytesize - offset)
        output << "\e]1337;FilePart="
        output.write(b64.to_slice[offset, count])
        output << "\a"
        offset += count
      end
      output << "\e]1337;FileEnd\a"
      output.flush
    end
  end
end
