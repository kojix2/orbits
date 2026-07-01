module Orbits
  enum Xform
    Boolean
    Linear
    Log
    LogLog
    Cubic
    Equalized

    def self.parse(value : String) : self
      case value.downcase
      when "boolean", "bool"               then Boolean
      when "linear"                        then Linear
      when "log"                           then Log
      when "loglog", "log-log"             then LogLog
      when "cubic"                         then Cubic
      when "equalized", "equalize", "hist" then Equalized
      else
        raise ArgumentError.new("unknown xform: #{value} (choose from #{names.map(&.downcase).join(", ")})")
      end
    end

    def cli_name : String
      to_s.downcase
    end
  end

  enum AttractorKind
    Clifford
    DeJong
    Ikeda
    Hopalong

    def self.parse(value : String) : self
      case value.downcase
      when "clifford"          then Clifford
      when "dejong", "de-jong" then DeJong
      when "ikeda"             then Ikeda
      when "hopalong"          then Hopalong
      else
        raise ArgumentError.new("unknown attractor: #{value} (choose from #{names.map(&.downcase).join(", ")})")
      end
    end

    def definition : Attractors::Base
      Attractors.resolve(self)
    end

    def default_params : Params
      definition.default_params
    end

    def default_window : Window
      definition.default_window
    end

    # Subcommand name as typed on the command line, e.g. `DeJong` -> "dejong".
    def cli_name : String
      to_s.downcase
    end

    def summary : String
      definition.summary
    end

    # Iteration formula, one string per line, for help output.
    def formula : Array(String)
      definition.formula
    end
  end

  struct Window
    getter xmin : Float64
    getter xmax : Float64
    getter ymin : Float64
    getter ymax : Float64

    def initialize(@xmin : Float64, @xmax : Float64, @ymin : Float64, @ymax : Float64)
      raise ArgumentError.new("invalid x window") if @xmin == @xmax
      raise ArgumentError.new("invalid y window") if @ymin == @ymax
    end

    def self.default : self
      new(-3.0, 3.0, -3.0, 3.0)
    end
  end

  # Mutable so a subcommand can allocate its attractor's default parameters
  # once and let each option handler rewrite a single field in place, rather
  # than rebuilding a fresh copy per option.
  class Params
    property a : Float64
    property b : Float64
    property c : Float64
    property d : Float64
    property x0 : Float64
    property y0 : Float64
    property theta : Float64?
    property dtheta : Float64

    def initialize(@a : Float64, @b : Float64, @c : Float64, @d : Float64,
                   @x0 : Float64 = 0.0, @y0 : Float64 = 0.0,
                   @theta : Float64? = nil, @dtheta : Float64 = 0.0)
    end

    # Independent copy with a new starting point, used to seed each orbit.
    def with_xy(x : Float64, y : Float64) : self
      copy = dup
      copy.x0 = x
      copy.y0 = y
      copy
    end

    def_equals_and_hash a, b, c, d, x0, y0, theta, dtheta
  end

  class Config
    property attractor : AttractorKind
    property params : Params
    property points : Int64
    property orbits : Int32
    property width : Int32
    property height : Int32
    property window : Window
    property xform : Xform
    property colormap : Colormap
    property protocol : TermImage::Protocol
    property output : String?
    property? print_params : Bool
    property? detect_only : Bool
    property? quiet : Bool

    # Single source of truth for the rendering defaults. Anything that needs to
    # know "is this value still the default?" (help text, the --print-params
    # reproduce command) reads these rather than repeating the literal, so a
    # change here can never silently drift out of sync with a copy elsewhere.
    DEFAULT_ATTRACTOR = AttractorKind::DeJong
    DEFAULT_POINTS    = 10_000_000_i64
    DEFAULT_ORBITS    =              1
    DEFAULT_WIDTH     =            640
    DEFAULT_HEIGHT    =            640
    BRAILLE_WIDTH     =            120
    BRAILLE_HEIGHT    =            120
    SHADES_WIDTH      =             60
    SHADES_HEIGHT     =             30
    DEFAULT_XFORM     = Xform::Equalized
    DEFAULT_COLORMAP  = Colormap::Gray

    def initialize(@attractor = DEFAULT_ATTRACTOR,
                   params : Params? = nil,
                   @points = DEFAULT_POINTS,
                   @orbits = DEFAULT_ORBITS,
                   @width = DEFAULT_WIDTH,
                   @height = DEFAULT_HEIGHT,
                   window : Window? = nil,
                   @xform = DEFAULT_XFORM,
                   @colormap = DEFAULT_COLORMAP,
                   @protocol = TermImage::Protocol::Auto,
                   @output = nil,
                   @print_params = false,
                   @detect_only = false,
                   @quiet = false)
      @params = params || @attractor.default_params
      @window = window || @attractor.default_window
    end

    def validate! : Nil
      raise ArgumentError.new("points must be positive") if @points < 1
      raise ArgumentError.new("orbits must be positive") if @orbits < 1
      raise ArgumentError.new("width must be positive") if @width < 1
      raise ArgumentError.new("height must be positive") if @height < 1
    end
  end
end
