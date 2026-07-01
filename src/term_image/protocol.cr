module TermImage
  enum Protocol
    Auto
    Iterm2
    Kitty
    Sixel
    Braille
    Shades

    def self.parse(value : String) : self
      case value.downcase
      when "auto"            then Auto
      when "iterm", "iterm2" then Iterm2
      when "kitty"           then Kitty
      when "sixel", "six"    then Sixel
      when "braille"         then Braille
      when "shades", "shade" then Shades
      else
        raise ArgumentError.new("unknown protocol: #{value} (choose from #{names.map(&.downcase).join(", ")})")
      end
    end

    def cli_name : String
      to_s.downcase
    end

    def text? : Bool
      braille? || shades?
    end
  end

  def self.show(image : Indexed, protocol : Protocol = Protocol::Auto, output : IO = STDOUT) : Nil
    write(protocol, output) do |target, selected|
      case selected
      in .auto?
        raise "auto protocol was not resolved"
      in .iterm2?
        Iterm2.write(target, image.to_rgba)
      in .kitty?
        Kitty.write(target, image.to_rgba)
      in .sixel?
        # Sixel currently writes the indexed palette directly and does not carry
        # RGBA alpha through the terminal protocol.
        Sixel.write(target, image)
      in .braille?
        Text.write_braille(target, image)
      in .shades?
        Text.write_shades(target, image)
      end
    end
  end

  def self.show(image : RGBA, protocol : Protocol = Protocol::Auto, output : IO = STDOUT) : Nil
    write(protocol, output) do |target, selected|
      case selected
      in .auto?
        raise "auto protocol was not resolved"
      in .iterm2?
        Iterm2.write(target, image)
      in .kitty?
        Kitty.write(target, image)
      in .sixel?
        Sixel.write(target, image.to_indexed)
      in .braille?
        Text.write_braille(target, image)
      in .shades?
        Text.write_shades(target, image)
      end
    end
  end

  private def self.write(protocol : Protocol, output : IO, & : IO, Protocol -> Nil) : Nil
    detection = detect(protocol)
    wrap_tmux = detection.tmux? && !detection.protocol.text?
    target = wrap_tmux ? IO::Memory.new : output
    yield target, detection.protocol

    if wrap_tmux && target.is_a?(IO::Memory)
      output << Tmux.wrap(target.to_slice)
    end
    output << '\n'
    output.flush
  end

  private def self.detect(protocol : Protocol) : Detection
    if protocol.auto?
      Detector.new.detect
    else
      Detection.new(protocol, Detector.new.detect.tmux?, "explicit")
    end
  end
end
