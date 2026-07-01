require "../spec_helper"

private def test_palette
  StaticArray(UInt32, 256).new { |i| (i.to_u32 << 16) | (i.to_u32 << 8) | i.to_u32 }
end

describe TermImage::Text do
  it "writes indexed braille with the standard 2x4 dot layout" do
    image = TermImage::Indexed.new(2, 4, Bytes[
      1, 1,
      1, 1,
      1, 1,
      1, 1,
    ], test_palette)
    io = IO::Memory.new

    TermImage::Text.write_braille(io, image)

    io.to_s.should eq("\e[38;2;1;1;1m⣿\e[0m")
  end

  it "pads odd indexed braille edges as background" do
    image = TermImage::Indexed.new(1, 1, Bytes[1], test_palette)
    io = IO::Memory.new

    TermImage::Text.write_braille(io, image)

    io.to_s.should eq("\e[38;2;1;1;1m⠁\e[0m")
  end

  it "keeps indexed braille index zero and transparency empty" do
    image = TermImage::Indexed.new(2, 1, Bytes[0_u8, 1_u8], test_palette, 1_u8)
    io = IO::Memory.new

    TermImage::Text.write_braille(io, image)

    io.to_s.should eq("⠀")
  end

  it "uses rgba luminance threshold for braille" do
    image = TermImage::RGBA.new(2, 4, Bytes[
      0, 0, 0, 255, 1, 1, 1, 255,
      255, 255, 255, 0, 255, 255, 255, 255,
      255, 255, 255, 255, 0, 0, 0, 255,
      0, 0, 0, 255, 255, 255, 255, 255,
    ])
    io = IO::Memory.new

    TermImage::Text.write_braille(io, image)

    io.to_s.should eq("\e[38;2;255;255;255m⢜\e[0m")
  end

  it "uses the highest-density braille dot's colormap color" do
    palette = test_palette
    palette[200] = 0x12ABEF_u32
    image = TermImage::Indexed.new(2, 1, Bytes[10_u8, 200_u8], palette)
    io = IO::Memory.new

    TermImage::Text.write_braille(io, image)

    io.to_s.should eq("\e[38;2;18;171;239m⠉\e[0m")
  end

  it "writes indexed shades at the configured thresholds" do
    image = TermImage::Indexed.new(8, 1, Bytes[
      0, 63, 64, 127, 128, 191, 192, 255,
    ], test_palette)
    io = IO::Memory.new

    TermImage::Text.write_shades(io, image)

    io.to_s.should eq(" \e[38;2;63;63;63m░\e[38;2;64;64;64m▒\e[38;2;127;127;127m▒\e[38;2;128;128;128m▓\e[38;2;191;191;191m▓\e[38;2;192;192;192m█\e[38;2;255;255;255m█\e[0m")
  end

  it "keeps transparent indexed shades empty" do
    image = TermImage::Indexed.new(2, 1, Bytes[255_u8, 1_u8], test_palette, 255_u8)
    io = IO::Memory.new

    TermImage::Text.write_shades(io, image)

    io.to_s.should eq(" \e[38;2;1;1;1m░\e[0m")
  end

  it "uses rgba luminance and alpha for shades" do
    image = TermImage::RGBA.new(4, 1, Bytes[
      0, 0, 0, 255,
      255, 255, 255, 0,
      128, 128, 128, 255,
      255, 255, 255, 255,
    ])
    io = IO::Memory.new

    TermImage::Text.write_shades(io, image)

    io.to_s.should eq("  \e[38;2;128;128;128m▓\e[38;2;255;255;255m█\e[0m")
  end

  it "uses an indexed image's colormap for shades" do
    palette = test_palette
    palette[128] = 0x12ABEF_u32
    image = TermImage::Indexed.new(2, 1, Bytes[128_u8, 128_u8], palette)
    io = IO::Memory.new

    TermImage::Text.write_shades(io, image)

    io.to_s.should eq("\e[38;2;18;171;239m▓▓\e[0m")
  end
end
