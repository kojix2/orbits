require "../spec_helper"

describe TermImage::RGBA do
  it "preserves colors when converting to an indexed image with up to 256 colors" do
    rgba = TermImage::RGBA.new(2, 1, Bytes[
      255, 0, 0, 255,
      0, 0, 255, 255,
    ])

    indexed = rgba.to_indexed

    indexed.indices.to_a.should eq([0_u8, 1_u8])
    indexed.palette[0].should eq(0xff0000_u32)
    indexed.palette[1].should eq(0x0000ff_u32)
    indexed.transparent_index.should be_nil
    indexed.to_rgba.pixels.to_a.should eq(rgba.pixels.to_a)
  end
end

describe TermImage::Indexed do
  it "keeps palette index 0 opaque by default" do
    palette = StaticArray(UInt32, 256).new { |i| i == 1 ? 0x112233_u32 : 0x000000_u32 }
    indexed = TermImage::Indexed.new(2, 1, Bytes[0_u8, 1_u8], palette)

    rgba = indexed.to_rgba

    rgba.pixels.to_a.should eq([
      0, 0, 0, 255,
      0x11, 0x22, 0x33, 255,
    ])
  end

  it "uses transparent alpha for the configured transparent index" do
    palette = StaticArray(UInt32, 256).new { |i| i == 1 ? 0x112233_u32 : 0x000000_u32 }
    indexed = TermImage::Indexed.new(2, 1, Bytes[0_u8, 1_u8], palette, 0_u8)

    rgba = indexed.to_rgba

    rgba.pixels.to_a.should eq([
      0, 0, 0, 0,
      0x11, 0x22, 0x33, 255,
    ])
  end
end
