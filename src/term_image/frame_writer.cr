module TermImage
  # Owns the terminal state needed for repeated in-place image updates. Frames
  # live in the alternate screen so an interrupted animation cannot leave a
  # stack of partial images in scrollback.
  class FrameWriter
    KITTY_PLACEMENT_ID = 1_u32

    getter protocol : Protocol

    @tmux : Bool

    def initialize(requested : Protocol = Protocol::Auto, @output : IO = STDOUT)
      detection = Detector.new.detect
      @protocol = requested.auto? ? detection.protocol : requested
      @tmux = detection.tmux?
      id = Random.rand(UInt32)
      @kitty_image_id = id.zero? ? 1_u32 : id
      @started = false
    end

    def start : Nil
      return if @started
      @output << "\e[?1049h\e[?25l\e[H"
      @output.flush
      @started = true
    end

    def write(image : Indexed) : Nil
      start unless @started
      @output << "\e[H"
      write_protocol(image)
      @output.flush
    end

    def finish : Nil
      return unless @started
      begin
        delete_kitty_image if @protocol.kitty?
      ensure
        @output << "\e[?25h\e[?1049l"
        @output.flush
        @started = false
      end
    end

    private def write_protocol(image : Indexed) : Nil
      target = wrapped_target
      case @protocol
      in .auto?
        raise "auto protocol was not resolved"
      in .iterm2?
        Iterm2.write(target, image.to_rgba)
      in .kitty?
        Kitty.write(target, image.to_rgba,
          image_id: @kitty_image_id,
          placement_id: KITTY_PLACEMENT_ID,
          move_cursor: false)
      in .sixel?
        Sixel.write(target, image)
      in .braille?
        Text.write_braille(target, image)
      in .shades?
        Text.write_shades(target, image)
      end
      flush_wrapped(target)
    end

    private def delete_kitty_image : Nil
      target = wrapped_target
      Kitty.delete(target, @kitty_image_id)
      flush_wrapped(target)
    end

    private def wrapped_target : IO
      wrap_tmux? ? IO::Memory.new : @output
    end

    private def flush_wrapped(target : IO) : Nil
      if wrap_tmux? && target.is_a?(IO::Memory)
        @output << Tmux.wrap(target.to_slice)
      end
    end

    private def wrap_tmux? : Bool
      @tmux && !@protocol.text?
    end
  end
end
