require "option_parser"
require "./cli/config_presenter"
require "./cli/output_writer"

module Orbits
  module CLI
    extend self

    def run(argv : Array(String), output : IO = STDOUT, error : IO = STDERR) : Int32
      config = parse_config(argv)

      if config.detect_only?
        detection = TermImage::Detector.new.detect
        output.puts "protocol: #{detection.protocol.cli_name}"
        output.puts "tmux: #{detection.tmux?}"
        output.puts "reason: #{detection.reason}"
        return 0
      end

      ConfigPresenter.new(config).write(error) if config.print_params?

      report_start(config, error, output.tty?)
      started = Time.instant
      interrupted = false
      animate = config.animation && output.tty?
      image = if animate
                animator = Animator.new(config, output)
                result = animator.render
                interrupted = animator.interrupted?
                report_morph_adjustment(config, animator.effective_morph_amount, error)
                result
              else
                Renderer.new(config).render
              end
      elapsed = Time.instant - started

      if path = config.output
        OutputWriter.new(path, image, config.protocol).write
        report_done(config, elapsed, "wrote #{path}", error)
      else
        report_done(config, elapsed, "displaying", error)
        TermImage.show(image, config.protocol, output)
      end
      interrupted ? 130 : 0
    rescue ex : ArgumentError
      error.puts "[orbits] #{ex.message}"
      error.puts "Run 'orbits --help' for usage."
      1
    rescue ex : Exception
      error.puts "[orbits] #{ex.message}"
      1
    end

    # Progress goes to stderr and only when it is a terminal, so it never
    # corrupts piped image bytes or a `--output` file redirect.
    private def report_start(config : Config, error : IO, output_tty : Bool) : Nil
      return if config.quiet? || !error.tty?
      orbits = config.orbits == 1 ? "1 orbit" : "#{config.orbits} orbits"
      seed = config.seed ? " — seed #{config.seed}" : ""
      animation_active = config.animation && output_tty
      action = animation_active ? "animating" : "rendering"
      animation = if animation_active && (mode = config.animation)
                    ", #{mode.cli_name}, #{config.fps} fps for #{config.duration}s"
                  else
                    ""
                  end
      error.puts "[orbits] #{action} #{config.attractor.to_s.downcase} — " \
                 "#{config.points.format} points, #{orbits}, #{config.width}x#{config.height}#{animation}#{seed}"
    end

    private def report_done(config : Config, elapsed : Time::Span, action : String, error : IO) : Nil
      return if config.quiet? || !error.tty?
      error.puts "[orbits] done in #{elapsed.total_seconds.round(2)}s (#{action})"
    end

    private def report_morph_adjustment(config : Config, amount : Float64?, error : IO) : Nil
      return unless amount && amount < config.morph_amount
      show_adjustment = config.print_params? || (!config.quiet? && error.tty?)
      return unless show_adjustment

      error.puts "[orbits] morph amount adjusted from #{config.morph_amount} to #{amount} to keep the loop visible"
    end

    # Column at which option descriptions align in help output.
    SUMMARY_WIDTH = 24

    def parse_config(argv : Array(String)) : Config
      config = Config.new
      state = ParseState.new

      parser = OptionParser.new do |opts|
        opts.summary_width = SUMMARY_WIDTH
        opts.banner = <<-BANNER
          orbits — render strange attractors in the terminal

          Usage: orbits [attractor] [options]

          Omit the attractor to select one randomly. Use a subcommand with
          --help to see its coefficient options, e.g. `orbits clifford --help`.
          BANNER
        opts.separator ""
        opts.separator "Attractors:"
        add_attractor_options(opts, config, state)
        add_common_options(opts, config, state)
        opts.separator ""
        opts.separator "Global options:"
        opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        opts.on("--version", "Print the version and exit") { puts VERSION; exit 0 }
        opts.on("--detect", "Print the detected terminal protocol") { config.detect_only = true }
        opts.separator ""
        opts.separator "Examples:"
        opts.separator "  orbits clifford --points 10M --orbits 4 --colormap fire"
        opts.separator "  orbits ikeda --u 0.9 --points 5M"
        opts.separator "  orbits --seed 42 --protocol shades --colormap turbo"
        opts.separator "  orbits clifford --seed 42 --animate reveal --duration 5"
        opts.separator "  orbits dejong --animate trail --trail 10K"
        opts.separator "  orbits ikeda --u 0.9 --animate morph --morph-amount 1.5"
        opts.unknown_args do |before_dash, after_dash|
          unknown = before_dash.first? || after_dash.first?
          raise ArgumentError.new("unknown argument: #{unknown}") if unknown
        end
      end

      parser.parse(argv)

      apply_animation_defaults(config, state)
      apply_protocol_default_size(config, state) unless config.detect_only?
      apply_random_selection(config, state) unless config.detect_only?
      config.validate!
      config
    end

    private class ParseState
      property? attractor_selected = false
      property? colormap_set = false
      property? randomize_params = true
      property? points_set = false
      property? size_set = false
      property? window_set = false
      property seed : UInt64? = nil
    end

    private def add_attractor_options(opts : OptionParser, config : Config, state : ParseState) : Nil
      opts.on("clifford", "Clifford attractor") do
        use_attractor(config, AttractorKind::Clifford, state)
        opts.banner = attractor_banner(config.attractor)
        opts.separator ""
        opts.separator "Clifford options:"
        add_abcd_options(opts, config, state)
        opts.on("--theta VALUE", "Enable theta modulation (default: #{config.params.theta})") { |v| config.params.theta = v.to_f64 }
        opts.on("--dtheta VALUE", "Theta increment (default: #{config.params.dtheta})") { |v| config.params.dtheta = v.to_f64 }
        add_xy_option(opts, config)
      end

      opts.on("dejong", "De Jong attractor") do
        use_attractor(config, AttractorKind::DeJong, state)
        opts.banner = attractor_banner(config.attractor)
        opts.separator ""
        opts.separator "De Jong options:"
        add_abcd_options(opts, config, state)
        add_xy_option(opts, config)
      end

      opts.on("ikeda", "Ikeda attractor") do
        use_attractor(config, AttractorKind::Ikeda, state)
        opts.banner = attractor_banner(config.attractor)
        opts.separator ""
        opts.separator "Ikeda options:"
        opts.on("--u VALUE", "Ikeda u parameter (default: #{config.params.a})") do |v|
          config.params.a = v.to_f64
          state.randomize_params = false
        end
        add_xy_option(opts, config)
      end

      opts.on("hopalong", "Hopalong attractor") do
        use_attractor(config, AttractorKind::Hopalong, state)
        opts.banner = attractor_banner(config.attractor)
        opts.separator ""
        opts.separator "Hopalong options:"
        opts.on("--a VALUE", "Hopalong a parameter (default: #{config.params.a})") do |v|
          config.params.a = v.to_f64
          state.randomize_params = false
        end
        opts.on("--b VALUE", "Hopalong b parameter (default: #{config.params.b})") do |v|
          config.params.b = v.to_f64
          state.randomize_params = false
        end
        opts.on("--c VALUE", "Hopalong c parameter (default: #{config.params.c})") do |v|
          config.params.c = v.to_f64
          state.randomize_params = false
        end
        add_xy_option(opts, config)
      end
    end

    private def add_common_options(opts : OptionParser, config : Config, state : ParseState) : Nil
      opts.separator ""
      opts.separator "Common options:"

      # Sampling: how many points to iterate, and across how many orbits.
      opts.on("-n", "--points N", "Point budget, K/M/G ok (default: #{humanize_count(config.points)})") do |v|
        config.points = parse_count(v)
        state.points_set = true
      end
      opts.on("--iterations N", "Alias for --points") do |v|
        config.points = parse_count(v)
        state.points_set = true
      end
      opts.on("--orbits N", "Number of independent orbits (default: #{config.orbits})") { |v| config.orbits = v.to_i }

      # Framing: pixel resolution and the world-coordinate region it maps to.
      opts.on("-s", "--size WxH", "Raster size (graphics: 640x640; Braille: 120x120; shades: 60x30)") do |v|
        w, h = parse_size(v)
        config.width = w
        config.height = h
        state.size_set = true
      end
      opts.on("--window X1,X2,Y1,Y2", "Override the world-coordinate window") do |v|
        config.window = parse_window(v)
        config.window_explicit = true
        state.window_set = true
      end

      # Appearance: density transform and colour palette.
      opts.on("--xform NAME", "boolean, linear, log, loglog, cubic, equalized (default)") { |v| config.xform = Xform.parse(v) }
      opts.on("--colormap NAME", "ice, fire, gr8, turbo, gray (random by default)") do |v|
        config.colormap = Colormap.parse(v)
        state.colormap_set = true
      end

      # Output: where the image goes and which terminal protocol to use.
      opts.on("-o", "--output PATH", "Write PNG, SIXEL, or text instead of displaying") { |v| config.output = v }
      opts.on("--protocol NAME", "auto (default), iterm2, kitty, sixel, braille, shades") { |v| config.protocol = TermImage::Protocol.parse(v) }

      # Diagnostics.
      opts.on("--seed N", "Seed random selection") { |v| state.seed = v.to_u64 }
      opts.on("--print-params", "Print selected parameters to stderr") { config.print_params = true }
      opts.on("-q", "--quiet", "Suppress the render status on stderr") { config.quiet = true }

      # Animation: shared timing plus controls specific to trail and morph.
      opts.separator ""
      opts.separator "Animation:"
      opts.separator "  Point defaults: reveal 10M total; trail 100K total; morph 1M/frame"
      opts.on("--animate MODE", "Animate in place: reveal, trail, morph") { |v| config.animation = AnimationMode.parse(v) }
      opts.on("--fps N", "Animation frame rate (default: #{config.fps})") { |v| config.fps = v.to_i }
      opts.on("--duration SECONDS", "Animation duration (default: #{config.duration})") { |v| config.duration = v.to_f64 }
      opts.on("--trail N", "Points retained by trail mode (default: #{humanize_count(config.trail_points)})") do |v|
        config.trail_points = parse_count(v)
      end
      opts.on("--morph-amount N", "Morph amplitude multiplier (default: #{config.morph_amount})") do |v|
        config.morph_amount = v.to_f64
      end
    end

    private def add_abcd_options(opts : OptionParser, config : Config, state : ParseState) : Nil
      params = config.params
      opts.on("--a VALUE", "Coefficient a (default: #{params.a})") do |v|
        config.params.a = v.to_f64
        state.randomize_params = false
      end
      opts.on("--b VALUE", "Coefficient b (default: #{params.b})") do |v|
        config.params.b = v.to_f64
        state.randomize_params = false
      end
      opts.on("--c VALUE", "Coefficient c (default: #{params.c})") do |v|
        config.params.c = v.to_f64
        state.randomize_params = false
      end
      opts.on("--d VALUE", "Coefficient d (default: #{params.d})") do |v|
        config.params.d = v.to_f64
        state.randomize_params = false
      end
      opts.on("--abcd A,B,C,D", "Set a,b,c,d (default: #{params.a},#{params.b},#{params.c},#{params.d})") do |v|
        a, b, c, d = parse_floats(v, 4)
        config.params.a, config.params.b, config.params.c, config.params.d = a, b, c, d
        state.randomize_params = false
      end
    end

    private def add_xy_option(opts : OptionParser, config : Config) : Nil
      params = config.params
      opts.on("--xy X,Y", "Initial point (default: #{params.x0},#{params.y0})") do |v|
        x, y = parse_floats(v, 2)
        config.params.x0, config.params.y0 = x, y
      end
    end

    private def use_attractor(config : Config, attractor : AttractorKind, state : ParseState) : Nil
      state.attractor_selected = true
      config.attractor = attractor
      config.params = attractor.default_params
      config.window = attractor.default_window unless state.window_set?
    end

    private def apply_animation_defaults(config : Config, state : ParseState) : Nil
      return if state.points_set?

      case config.animation
      when AnimationMode::Trail
        config.points = Config::DEFAULT_TRAIL_BUDGET
      when AnimationMode::Morph
        config.points = Config::DEFAULT_MORPH_POINTS
      end
    end

    # Subcommand banner: the attractor's name, its iteration formula, then the
    # usage line. Shown above the per-attractor option list in `<sub> --help`.
    private def attractor_banner(kind : AttractorKind) : String
      String.build do |io|
        io << kind.summary << '\n'
        io << '\n'
        kind.formula.each { |line| io << "  " << line << '\n' }
        io << '\n'
        io << "Usage: orbits " << kind.cli_name << " [options]"
      end
    end

    private def parse_window(value : String) : Window
      xmin, xmax, ymin, ymax = parse_floats(value, 4)
      Window.new(xmin, xmax, ymin, ymax)
    end

    private def parse_floats(value : String, expected : Int32) : Array(Float64)
      fields = value.split(',').map(&.strip)
      raise ArgumentError.new("expected #{expected} comma-separated values") unless fields.size == expected
      raise ArgumentError.new("expected #{expected} comma-separated values") if fields.any?(&.empty?)
      fields.map(&.to_f64)
    end

    private def parse_size(value : String) : {Int32, Int32}
      fields = value.downcase.split('x')
      raise ArgumentError.new("size must be WxH") unless fields.size == 2
      {fields[0].to_i, fields[1].to_i}
    end

    private def parse_count(value : String) : Int64
      number = value.strip.upcase
      multiplier = case number[-1]?
                   when 'K' then 1_000_i64
                   when 'M' then 1_000_000_i64
                   when 'G' then 1_000_000_000_i64
                   else          1_i64
                   end
      number = number[0, number.size - 1] if multiplier != 1
      raise ArgumentError.new("count requires a number") if number.empty?
      (number.to_f64 * multiplier).to_i64
    end

    # Inverse of parse_count for compact help defaults: 10_000_000 -> "10M".
    private def humanize_count(n : Int64) : String
      return "#{n // 1_000_000_000}G" if n >= 1_000_000_000 && n % 1_000_000_000 == 0
      return "#{n // 1_000_000}M" if n >= 1_000_000 && n % 1_000_000 == 0
      return "#{n // 1_000}K" if n >= 1_000 && n % 1_000 == 0
      n.to_s
    end

    # Selects a colormap unless the user supplied one. With no subcommand it
    # also selects an attractor, then picks coefficients likely to render well.
    # One RNG drives every stage for complete --seed reproduction.
    private def apply_random_selection(config : Config, state : ParseState) : Nil
      # Generate the seed explicitly even when the user did not provide one.
      # Keeping it on the config lets the UI show the value needed to recreate
      # an otherwise one-off random draw.
      seed = state.seed || Random.rand(UInt64)
      config.seed = seed
      rng = Random.new(seed)
      unless state.attractor_selected?
        attractors = AttractorKind.values
        selected = attractors[rng.rand(attractors.size)]
        config.attractor = selected
        config.params = selected.default_params
        config.window = selected.default_window unless state.window_set?
      end
      unless state.colormap_set?
        colormaps = Colormap.values
        config.colormap = colormaps[rng.rand(colormaps.size)]
      end
      return unless state.randomize_params?

      params, window = RandomParams.choose(config.attractor, config.params, rng)
      config.params = params
      config.window = window unless state.window_set?
    end

    private def apply_protocol_default_size(config : Config, state : ParseState) : Nil
      return if state.size_set?

      protocol = config.protocol.auto? ? TermImage::Detector.new.detect.protocol : config.protocol
      if protocol.braille?
        config.width = Config::BRAILLE_WIDTH
        config.height = Config::BRAILLE_HEIGHT
      elsif protocol.shades?
        config.width = Config::SHADES_WIDTH
        config.height = Config::SHADES_HEIGHT
      end
    end
  end
end
