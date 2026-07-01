require "../spec_helper"

module PNGSpec
  extend self

  def chunks(png : Bytes)
    chunks = [] of NamedTuple(type: String, data: Bytes)
    offset = TermImage::PNG::SIGNATURE.size

    while offset < png.size
      length = read_u32(png[offset, 4]).to_i
      type = String.new(png[offset + 4, 4])
      data = png[offset + 8, length]
      chunks << {type: type, data: data}
      offset += 12 + length
    end

    chunks
  end

  def read_u32(bytes : Bytes) : UInt32
    (bytes[0].to_u32 << 24) | (bytes[1].to_u32 << 16) | (bytes[2].to_u32 << 8) | bytes[3].to_u32
  end

  def inflate(bytes : Bytes) : Bytes
    io = IO::Memory.new(bytes)
    Compress::Zlib::Reader.open(io) do |zlib|
      zlib.getb_to_end
    end
  end
end

describe TermImage::PNG do
  it "writes a PNG signature and IHDR dimensions" do
    rgba = TermImage::RGBA.new(1, 1, Bytes[255, 0, 0, 255])
    png = TermImage::PNG.encode(rgba)

    png[0, 8].should eq(TermImage::PNG::SIGNATURE)
    png[12, 4].should eq("IHDR".to_slice)
    png[16, 4].should eq(Bytes[0, 0, 0, 1])
    png[20, 4].should eq(Bytes[0, 0, 0, 1])
  end

  it "writes IHDR, IDAT, and IEND chunks with unfiltered RGBA scanlines" do
    rgba = TermImage::RGBA.new(2, 1, Bytes[255, 0, 0, 255, 0, 128, 255, 255])
    png = TermImage::PNG.encode(rgba)

    chunks = PNGSpec.chunks(png)
    chunks.map(&.[:type]).should eq(["IHDR", "IDAT", "IEND"])
    chunks[0][:data][8].should eq(8_u8) # bit depth
    chunks[0][:data][9].should eq(6_u8) # RGBA color type

    raw = PNGSpec.inflate(chunks[1][:data])
    raw.should eq(Bytes[0, 255, 0, 0, 255, 0, 128, 255, 255])
  end
end
