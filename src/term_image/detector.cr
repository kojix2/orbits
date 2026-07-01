module TermImage
  struct Detection
    getter protocol : Protocol
    getter? tmux : Bool
    getter reason : String

    def initialize(@protocol : Protocol, @tmux : Bool, @reason : String)
    end
  end

  class Detector
    def detect(env = ENV) : Detection
      tmux = tmux?(env)

      if iterm?(env)
        return Detection.new(Protocol::Iterm2, tmux, "iTerm2-like environment")
      end
      if kitty?(env)
        return Detection.new(Protocol::Kitty, tmux, "Kitty graphics-capable environment")
      end
      if sixel_likely?(env)
        return Detection.new(Protocol::Sixel, tmux, "Sixel-capable TERM")
      end

      # Text output is safe even when terminal graphics support is unknown.
      Detection.new(Protocol::Braille, tmux, "no graphics protocol detected")
    end

    private def iterm?(env) : Bool
      env["LC_TERMINAL"]? == "iTerm2" ||
        env["TERM_PROGRAM"]? == "iTerm.app" ||
        env["TERM_PROGRAM"]? == "iTerm2"
    end

    private def kitty?(env) : Bool
      term = env["TERM"]?.try(&.downcase) || ""
      program = env["TERM_PROGRAM"]?.try(&.downcase) || ""
      env.has_key?("KITTY_WINDOW_ID") ||
        term == "xterm-kitty" ||
        term == "xterm-ghostty" ||
        program == "wezterm" ||
        env.has_key?("WEZTERM_EXECUTABLE") ||
        env.has_key?("GHOSTTY_RESOURCES_DIR")
    end

    private def sixel_likely?(env) : Bool
      term = env["TERM"]?.try(&.downcase) || ""
      term.includes?("sixel") || term.includes?("mlterm") || term.includes?("mintty")
    end

    private def tmux?(env) : Bool
      term = env["TERM"]?.try(&.downcase) || ""
      env.has_key?("TMUX") || term.starts_with?("screen") || term.starts_with?("tmux")
    end
  end
end
