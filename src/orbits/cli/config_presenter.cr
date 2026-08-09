module Orbits
  module CLI
    # Formats the human-readable parameter summary separately from parsing and
    # execution. The reproduction command intentionally retains full precision.
    private class ConfigPresenter
      METADATA_WIDTH = 8 # "colormap", the widest metadata label

      def initialize(@config : Config)
      end

      def write(output : IO) : Nil
        output << '\n'
        output << "  orbits / " << @config.attractor.cli_name << "\n\n"
        write_coefficients(output)
        write_metadata(output)
        output << "  reproduce ->\n"
        output << "    " << reproduction_command << "\n\n"
      end

      private def write_coefficients(output : IO) : Nil
        fields = parameter_fields
        label_width = fields.max_of { |label, _| label.size }
        values = fields.map { |_, value| format_float(value) }
        value_width = values.max_of(&.size)

        fields.each_with_index.each_slice(2) do |row|
          cells = row.map do |(label, _), index|
            "#{label.ljust(label_width)}  #{values[index].rjust(value_width)}"
          end
          output << "  " << cells.join("      ") << '\n'
        end
        output << '\n'
      end

      private def write_metadata(output : IO) : Nil
        params = @config.params
        window = @config.window
        output << "  " << "start".ljust(METADATA_WIDTH) << "  "
        output << format_float(params.x0) << ", " << format_float(params.y0) << '\n'
        if theta = params.theta
          output << "  " << "theta".ljust(METADATA_WIDTH) << "  "
          output << format_float(theta) << "  (" << format_signed(params.dtheta) << " / step)\n"
        end
        output << "  " << "window".ljust(METADATA_WIDTH) << "  x ["
        output << format_float(window.xmin) << ", " << format_float(window.xmax) << "]"
        output << "   y [" << format_float(window.ymin) << ", " << format_float(window.ymax) << "]\n"
        output << "  " << "colormap".ljust(METADATA_WIDTH) << "  " << @config.colormap.cli_name << "\n\n"
        if seed = @config.seed
          output << "  " << "seed".ljust(METADATA_WIDTH) << "  " << seed << "\n\n"
        end
      end

      # Only parameters used by the selected map belong in the summary.
      private def parameter_fields : Array({String, Float64})
        params = @config.params
        case @config.attractor
        in AttractorKind::Ikeda
          [{"u", params.a}]
        in AttractorKind::Hopalong
          [{"a", params.a}, {"b", params.b}, {"c", params.c}]
        in AttractorKind::Clifford, AttractorKind::DeJong
          [{"a", params.a}, {"b", params.b}, {"c", params.c}, {"d", params.d}]
        end
      end

      private def reproduction_command : String
        params = @config.params
        window = @config.window
        String.build do |output|
          append_argument = ->(argument : String) do
            {% if flag?(:win32) %}
              output << ' ' << argument
            {% else %}
              output << " \\" << '\n' << "      " << argument
            {% end %}
          end

          output << "orbits " << @config.attractor.cli_name
          append_argument.call("--seed #{@config.seed}") if @config.seed
          append_parameters(append_argument)
          append_argument.call("--xy #{params.x0},#{params.y0}") unless params.x0.zero? && params.y0.zero?
          if theta = params.theta
            append_argument.call("--theta #{theta}")
            append_argument.call("--dtheta #{params.dtheta}")
          end
          append_argument.call("--window #{window.xmin},#{window.xmax},#{window.ymin},#{window.ymax}")
          append_argument.call("--colormap #{@config.colormap.cli_name}")
          append_argument.call("-n #{@config.points}") unless @config.points == Config::DEFAULT_POINTS
          append_argument.call("--orbits #{@config.orbits}") unless @config.orbits == Config::DEFAULT_ORBITS
          unless @config.width == Config::DEFAULT_WIDTH && @config.height == Config::DEFAULT_HEIGHT
            append_argument.call("-s #{@config.width}x#{@config.height}")
          end
          append_argument.call("--xform #{@config.xform.cli_name}") unless @config.xform == Config::DEFAULT_XFORM
          if animation = @config.animation
            append_argument.call("--animate #{animation.cli_name}")
            append_argument.call("--fps #{@config.fps}") unless @config.fps == Config::DEFAULT_FPS
            append_argument.call("--duration #{@config.duration}") unless @config.duration == Config::DEFAULT_DURATION
            if animation.trail? && @config.trail_points != Config::DEFAULT_TRAIL_POINTS
              append_argument.call("--trail #{@config.trail_points}")
            end
            if animation.morph? && @config.morph_amount != Config::DEFAULT_MORPH_AMOUNT
              append_argument.call("--morph-amount #{@config.morph_amount}")
            end
          end
        end
      end

      private def append_parameters(append_argument : Proc(String, Nil)) : Nil
        params = @config.params
        case @config.attractor
        in AttractorKind::Ikeda
          append_argument.call("--u #{params.a}")
        in AttractorKind::Hopalong
          append_argument.call("--a #{params.a}")
          append_argument.call("--b #{params.b}")
          append_argument.call("--c #{params.c}")
        in AttractorKind::Clifford, AttractorKind::DeJong
          append_argument.call("--abcd #{params.a},#{params.b},#{params.c},#{params.d}")
        end
      end

      private def format_float(value : Float64) : String
        formatted = "%.6f" % value
        formatted = formatted.rstrip('0').rstrip('.') if formatted.includes?('.')
        formatted == "-0" ? "0" : formatted
      end

      private def format_signed(value : Float64) : String
        value < 0 ? format_float(value) : "+#{format_float(value)}"
      end
    end
  end
end
