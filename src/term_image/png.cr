module TermImage
  module PNG
    extend self

    SIGNATURE = Bytes[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

    def encode(image : RGBA) : Bytes
      io = IO::Memory.new
      io.write(SIGNATURE)

      ihdr = IO::Memory.new
      write_u32(ihdr, image.width.to_u32)
      write_u32(ihdr, image.height.to_u32)
      ihdr.write_byte(8_u8) # bit depth
      ihdr.write_byte(6_u8) # RGBA
      ihdr.write_byte(0_u8) # compression
      ihdr.write_byte(0_u8) # filter
      ihdr.write_byte(0_u8) # interlace
      chunk(io, "IHDR", ihdr.to_slice)

      raw = scanlines(image)
      compressed = IO::Memory.new
      Compress::Zlib::Writer.open(compressed) do |zlib|
        zlib.write(raw)
      end
      chunk(io, "IDAT", compressed.to_slice)
      chunk(io, "IEND", Bytes.new(0))

      io.to_slice
    end

    private def scanlines(image : RGBA) : Bytes
      stride = image.width * 4
      raw = Bytes.new((stride + 1) * image.height)
      src = 0
      dst = 0
      image.height.times do
        raw[dst] = 0_u8
        dst += 1
        raw[dst, stride].copy_from(image.pixels[src, stride])
        src += stride
        dst += stride
      end
      raw
    end

    private def chunk(io : IO, type : String, data : Bytes) : Nil
      type_bytes = type.to_slice
      write_u32(io, data.size.to_u32)
      io.write(type_bytes)
      io.write(data)
      write_u32(io, crc32(type_bytes, data))
    end

    private def write_u32(io : IO, value : UInt32) : Nil
      io.write_byte(((value >> 24) & 0xff).to_u8)
      io.write_byte(((value >> 16) & 0xff).to_u8)
      io.write_byte(((value >> 8) & 0xff).to_u8)
      io.write_byte((value & 0xff).to_u8)
    end

    private def crc32(type : Bytes, data : Bytes) : UInt32
      crc = 0xffffffff_u32
      type.each { |byte| crc = update_crc(crc, byte) }
      data.each { |byte| crc = update_crc(crc, byte) }
      crc ^ 0xffffffff_u32
    end

    private def update_crc(crc : UInt32, byte : UInt8) : UInt32
      c = crc ^ byte.to_u32
      8.times do
        c = (c & 1 == 1) ? (0xedb88320_u32 ^ (c >> 1)) : (c >> 1)
      end
      c
    end
  end
end
