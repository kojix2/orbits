module TermImage
  module Kitty
    extend self

    CHUNK_SIZE = 4096

    def write(output : IO, image : RGBA, rows : Int32? = nil, cols : Int32? = nil,
              image_id : UInt32? = nil, placement_id : UInt32? = nil,
              move_cursor : Bool = true) : Nil
      png = PNG.encode(image)
      b64 = Base64.strict_encode(png)
      offset = 0
      first = true
      while offset < b64.bytesize
        count = Math.min(CHUNK_SIZE, b64.bytesize - offset)
        more = offset + count < b64.bytesize ? 1 : 0
        if first
          output << "\e_Gf=100,a=T,q=2"
          output << ",i=#{image_id}" if image_id
          output << ",p=#{placement_id}" if placement_id
          output << ",C=1" unless move_cursor
          output << ",r=#{rows}" if rows
          output << ",c=#{cols}" if cols
          output << ",m=#{more};"
          first = false
        else
          output << "\e_Gm=#{more};"
        end
        output.write(b64.to_slice[offset, count])
        output << "\e\\"
        offset += count
      end
      output.flush
    end

    def delete(output : IO, image_id : UInt32) : Nil
      output << "\e_Ga=d,d=I,i=#{image_id},q=2\e\\"
      output.flush
    end
  end
end
