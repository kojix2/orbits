require "../spec_helper"

describe TermImage::Iterm2 do
  it "emits OSC 1337 multipart records" do
    io = IO::Memory.new
    image = TermImage::RGBA.new(1, 1, Bytes[255, 0, 0, 255])
    TermImage::Iterm2.write(io, image)
    s = io.to_s
    s.should contain("]1337;MultipartFile=")
    s.should contain("]1337;FilePart=")
    s.should contain("]1337;FileEnd")
  end
end

describe TermImage::Kitty do
  it "emits kitty graphics records" do
    io = IO::Memory.new
    image = TermImage::RGBA.new(1, 1, Bytes[255, 0, 0, 255])
    TermImage::Kitty.write(io, image)
    s = io.to_s
    s.should contain("\e_G")
    s.should contain("f=100")
    s.should contain("a=T")
    s.should contain("\e\\")
  end
end

describe TermImage::Sixel do
  it "emits a sixel DCS" do
    io = IO::Memory.new
    palette = StaticArray(UInt32, 256).new { |i| (i.to_u32 << 16) | (i.to_u32 << 8) | i.to_u32 }
    image = TermImage::Indexed.new(1, 1, Bytes[255], palette)
    TermImage::Sixel.write(io, image)
    s = io.to_s
    s.should start_with("\eP0;1q")
    s.should contain("#255")
    s.should end_with("\e\\")
  end
end

describe TermImage::Detector do
  it "falls back to braille without graphics protocol evidence" do
    detection = TermImage::Detector.new.detect({} of String => String)

    detection.protocol.braille?.should be_true
    detection.reason.should eq("no graphics protocol detected")
  end

  it "keeps sixel when TERM indicates sixel support" do
    detection = TermImage::Detector.new.detect({"TERM" => "xterm-sixel"})

    detection.protocol.sixel?.should be_true
    detection.reason.should eq("Sixel-capable TERM")
  end

  it "does not treat a generic xterm as sixel evidence" do
    detection = TermImage::Detector.new.detect({"TERM" => "xterm-256color"})

    detection.protocol.braille?.should be_true
  end
end

describe TermImage do
  it "parses text protocols" do
    TermImage::Protocol.parse("braille").braille?.should be_true
    TermImage::Protocol.parse("shades").shades?.should be_true
  end

  it "reports valid protocol names for unknown values" do
    expect_raises(ArgumentError, "unknown protocol: nope (choose from auto, iterm2, kitty, sixel, braille, shades)") do
      TermImage::Protocol.parse("nope")
    end
  end

  it "ends displayed images with a newline" do
    io = IO::Memory.new
    palette = StaticArray(UInt32, 256).new { |i| (i.to_u32 << 16) | (i.to_u32 << 8) | i.to_u32 }
    image = TermImage::Indexed.new(1, 1, Bytes[255], palette)

    TermImage.show(image, TermImage::Protocol::Sixel, io)

    io.to_s.should end_with("\e\\\n")
  end

  it "shows indexed text protocols with a newline" do
    io = IO::Memory.new
    palette = StaticArray(UInt32, 256).new { |i| (i.to_u32 << 16) | (i.to_u32 << 8) | i.to_u32 }
    image = TermImage::Indexed.new(1, 1, Bytes[255], palette)

    TermImage.show(image, TermImage::Protocol::Braille, io)

    io.to_s.should eq("\e[38;2;255;255;255m⠁\e[0m\n")
  end

  it "shows rgba shades with their source color" do
    io = IO::Memory.new
    image = TermImage::RGBA.new(1, 1, Bytes[255, 255, 255, 255])

    TermImage.show(image, TermImage::Protocol::Shades, io)

    io.to_s.should eq("\e[38;2;255;255;255m█\e[0m\n")
  end

  it "does not tmux-wrap text protocol output" do
    previous = ENV["TMUX"]?
    ENV["TMUX"] = "/tmp/tmux-test"
    begin
      io = IO::Memory.new
      palette = StaticArray(UInt32, 256).new { |i| (i.to_u32 << 16) | (i.to_u32 << 8) | i.to_u32 }
      image = TermImage::Indexed.new(1, 1, Bytes[255], palette)

      TermImage.show(image, TermImage::Protocol::Braille, io)

      io.to_s.should eq("\e[38;2;255;255;255m⠁\e[0m\n")
      io.to_s.should_not contain("\ePtmux;")
    ensure
      if value = previous
        ENV["TMUX"] = value
      else
        ENV.delete("TMUX")
      end
    end
  end
end
