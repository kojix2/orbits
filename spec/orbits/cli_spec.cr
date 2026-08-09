require "../spec_helper"

class TTYMemory < IO::Memory
  def tty? : Bool
    true
  end
end

describe Orbits::CLI do
  it "parses numeric CLI options into a config" do
    config = Orbits::CLI.parse_config([
      "clifford",
      "--abcd=-1.0,-1.1,-1.2,-1.3",
      "--xy=0.25,-0.5",
      "--theta=0.1",
      "--dtheta=0.01",
      "--window=-2,2,-3,3",
      "--points=1.5K",
      "--orbits=4",
      "--size=320x240",
      "--xform=loglog",
      "--colormap=fire",
      "--protocol=kitty",
      "--output=out.png",
      "--print-params",
    ])

    config.attractor.clifford?.should be_true
    config.params.a.should eq(-1.0)
    config.params.b.should eq(-1.1)
    config.params.c.should eq(-1.2)
    config.params.d.should eq(-1.3)
    config.params.x0.should eq(0.25)
    config.params.y0.should eq(-0.5)
    config.params.theta.should eq(0.1)
    config.params.dtheta.should eq(0.01)
    config.window.xmin.should eq(-2.0)
    config.window.xmax.should eq(2.0)
    config.window.ymin.should eq(-3.0)
    config.window.ymax.should eq(3.0)
    config.points.should eq(1_500)
    config.orbits.should eq(4)
    config.width.should eq(320)
    config.height.should eq(240)
    config.xform.log_log?.should be_true
    config.colormap.fire?.should be_true
    config.protocol.kitty?.should be_true
    config.output.should eq("out.png")
    config.print_params?.should be_true
  end

  it "parses attractor subcommands" do
    config = Orbits::CLI.parse_config(["dejong", "--points=10K"])

    config.attractor.de_jong?.should be_true
    config.params.should_not eq(Orbits::AttractorKind::DeJong.default_params)
    config.points.should eq(10_000)
  end

  it "randomly selects an attractor and colormap without a subcommand" do
    configs = (1_u64..8_u64).map do |seed|
      Orbits::CLI.parse_config(["--seed=#{seed}"])
    end

    configs.map(&.attractor).uniq!.size.should be > 1
    configs.map(&.colormap).uniq!.size.should be > 1
  end

  it "randomly selects a colormap for an explicit subcommand" do
    colormaps = (1_u64..8_u64).map do |seed|
      Orbits::CLI.parse_config(["clifford", "--seed=#{seed}"]).colormap
    end

    colormaps.uniq!.size.should be > 1
  end

  it "keeps an explicitly selected subcommand colormap" do
    config = Orbits::CLI.parse_config(["clifford", "--seed=42", "--colormap=ice"])

    config.colormap.ice?.should be_true
  end

  it "randomizes explicit subcommands unless coefficients are set" do
    config = Orbits::CLI.parse_config(["clifford"])

    config.params.should_not eq(Orbits::AttractorKind::Clifford.default_params)
    config.window.should_not eq(Orbits::AttractorKind::Clifford.default_window)
  end

  it "parses generic attractor parameters" do
    config = Orbits::CLI.parse_config(["ikeda", "--u=0.92", "--xy=0.2,0.3"])

    config.attractor.ikeda?.should be_true
    config.params.a.should eq(0.92)
    config.params.b.should eq(0.0)
    config.params.x0.should eq(0.2)
    config.params.y0.should eq(0.3)
  end

  it "parses attractor-specific coefficient options" do
    dejong = Orbits::CLI.parse_config(["dejong", "--a=1.0", "--b=2.0", "--c=3.0", "--d=4.0"])
    hopalong = Orbits::CLI.parse_config(["hopalong", "--a=0.5", "--b=1.5", "--c=-0.25"])

    dejong.params.a.should eq(1.0)
    dejong.params.b.should eq(2.0)
    dejong.params.c.should eq(3.0)
    dejong.params.d.should eq(4.0)
    hopalong.params.a.should eq(0.5)
    hopalong.params.b.should eq(1.5)
    hopalong.params.c.should eq(-0.25)
    hopalong.params.d.should eq(0.0)
  end

  it "rejects malformed fixed-width options" do
    expect_raises(ArgumentError, "expected 4 comma-separated values") do
      Orbits::CLI.parse_config(["clifford", "--abcd=1,2,3"])
    end

    expect_raises(ArgumentError, "expected 4 comma-separated values") do
      Orbits::CLI.parse_config(["clifford", "--abcd=1,2,,4"])
    end

    expect_raises(ArgumentError, "size must be WxH") do
      Orbits::CLI.parse_config(["clifford", "--size=640"])
    end
  end

  it "rejects attractor parameter options before a subcommand" do
    expect_raises(ArgumentError, "unknown argument: --a=1.0") do
      Orbits::CLI.parse_config(["--a=1.0", "dejong"])
    end

    expect_raises(ArgumentError, "unknown argument: --xy=0.2,0.3") do
      Orbits::CLI.parse_config(["--xy=0.2,0.3", "ikeda"])
    end
  end

  it "keeps iterations as a compatibility alias for points" do
    config = Orbits::CLI.parse_config(["clifford", "--iterations=2K"])

    config.points.should eq(2_000)
  end

  it "rejects non-positive point and orbit counts" do
    expect_raises(ArgumentError, "points must be positive") do
      Orbits::CLI.parse_config(["clifford", "--points=0"])
    end

    expect_raises(ArgumentError, "orbits must be positive") do
      Orbits::CLI.parse_config(["clifford", "--orbits=0"])
    end
  end

  it "rejects count suffixes without a number" do
    expect_raises(ArgumentError, "count requires a number") do
      Orbits::CLI.parse_config(["clifford", "--points=M"])
    end
  end

  it "accepts common options without or before a subcommand" do
    automatic = Orbits::CLI.parse_config([
      "--protocol=shades",
      "--size=80x40",
      "--colormap=ice",
      "--seed=42",
    ])
    explicit = Orbits::CLI.parse_config(["--points=10K", "dejong"])

    automatic.protocol.shades?.should be_true
    automatic.width.should eq(80)
    automatic.height.should eq(40)
    automatic.colormap.ice?.should be_true
    explicit.attractor.de_jong?.should be_true
    explicit.points.should eq(10_000)
  end

  it "rejects an unknown colormap with the valid names" do
    expect_raises(ArgumentError, /unknown colormap: nope/) do
      Orbits::CLI.parse_config(["clifford", "--colormap=nope"])
    end
  end

  it "rejects unknown choice options with valid names" do
    expect_raises(ArgumentError, "unknown xform: nope (choose from boolean, linear, log, loglog, cubic, equalized)") do
      Orbits::CLI.parse_config(["clifford", "--xform=nope"])
    end

    expect_raises(ArgumentError, "unknown protocol: nope (choose from auto, iterm2, kitty, sixel, braille, shades)") do
      Orbits::CLI.parse_config(["clifford", "--protocol=nope"])
    end

    expect_raises(ArgumentError, "unknown animation mode: nope (choose from reveal, trail, morph)") do
      Orbits::CLI.parse_config(["clifford", "--animate=nope"])
    end
  end

  it "accepts --detect as a global flag with or without a subcommand" do
    Orbits::CLI.parse_config(["--detect"]).detect_only?.should be_true

    with_subcommand = Orbits::CLI.parse_config(["clifford", "--detect"])
    with_subcommand.detect_only?.should be_true
    with_subcommand.attractor.clifford?.should be_true
  end

  it "parses --quiet to suppress render status" do
    Orbits::CLI.parse_config(["clifford"]).quiet?.should be_false
    Orbits::CLI.parse_config(["clifford", "--quiet"]).quiet?.should be_true
    Orbits::CLI.parse_config(["clifford", "-q"]).quiet?.should be_true
  end

  it "parses reveal animation controls" do
    config = Orbits::CLI.parse_config([
      "clifford",
      "--seed=42",
      "--animate=reveal",
      "--fps=24",
      "--duration=2.5",
    ])

    config.animation.should eq(Orbits::AnimationMode::Reveal)
    config.fps.should eq(24)
    config.duration.should eq(2.5)
  end

  it "parses trail and morph animation controls" do
    trail = Orbits::CLI.parse_config([
      "dejong", "--seed=42", "--animate=trail", "--trail=250K",
    ])
    morph = Orbits::CLI.parse_config([
      "ikeda", "--u=0.9", "--animate=morph", "--morph-amount=1.5",
    ])

    trail.animation.should eq(Orbits::AnimationMode::Trail)
    trail.trail_points.should eq(250_000)
    morph.animation.should eq(Orbits::AnimationMode::Morph)
    morph.morph_amount.should eq(1.5)
  end

  it "uses animation-specific default point budgets" do
    reveal = Orbits::CLI.parse_config(["clifford", "--seed=42", "--animate=reveal"])
    trail = Orbits::CLI.parse_config(["clifford", "--seed=42", "--animate=trail"])
    morph = Orbits::CLI.parse_config(["clifford", "--seed=42", "--animate=morph"])
    explicit = Orbits::CLI.parse_config(["clifford", "--seed=42", "--animate=morph", "--points=2M"])

    reveal.points.should eq(Orbits::Config::DEFAULT_POINTS)
    trail.points.should eq(Orbits::Config::DEFAULT_TRAIL_BUDGET)
    trail.trail_points.should eq(Orbits::Config::DEFAULT_TRAIL_POINTS)
    morph.points.should eq(Orbits::Config::DEFAULT_MORPH_POINTS)
    explicit.points.should eq(2_000_000)
  end

  it "validates animation controls and output" do
    expect_raises(ArgumentError, "fps must be positive") do
      Orbits::CLI.parse_config(["clifford", "--animate=reveal", "--fps=0"])
    end
    expect_raises(ArgumentError, "duration must be finite and positive") do
      Orbits::CLI.parse_config(["clifford", "--animate=reveal", "--duration=0"])
    end
    expect_raises(ArgumentError, "animation cannot be combined with --output yet") do
      Orbits::CLI.parse_config(["clifford", "--animate=reveal", "--output=out.png"])
    end
    expect_raises(ArgumentError, "trail point count must be positive") do
      Orbits::CLI.parse_config(["clifford", "--animate=trail", "--trail=0"])
    end
    expect_raises(ArgumentError, /trail point count must not exceed/) do
      Orbits::CLI.parse_config(["clifford", "--animate=trail", "--trail=11M"])
    end
    expect_raises(ArgumentError, "morph amount must be finite and positive") do
      Orbits::CLI.parse_config(["clifford", "--animate=morph", "--morph-amount=0"])
    end
  end

  it "ignores unused animation timing controls for a static render" do
    Orbits::CLI.parse_config(["clifford", "--fps=0", "--duration=0"]).animation.should be_nil
  end

  it "parses text protocols" do
    Orbits::CLI.parse_config(["dejong", "--protocol=braille"]).protocol.braille?.should be_true
    Orbits::CLI.parse_config(["dejong", "--protocol=shades"]).protocol.shades?.should be_true
  end

  it "uses a 120x120 default raster for braille" do
    config = Orbits::CLI.parse_config(["dejong", "--protocol=braille", "--seed=42"])

    config.width.should eq(120)
    config.height.should eq(120)
  end

  it "keeps an explicit braille raster size" do
    config = Orbits::CLI.parse_config(["dejong", "--protocol=braille", "--size=80x40", "--seed=42"])

    config.width.should eq(80)
    config.height.should eq(40)
  end

  it "uses a 60x30 default raster for shades" do
    config = Orbits::CLI.parse_config(["dejong", "--protocol=shades", "--seed=42"])

    config.width.should eq(60)
    config.height.should eq(30)
  end

  it "keeps an explicit shades raster size" do
    config = Orbits::CLI.parse_config(["dejong", "--protocol=shades", "--size=90x45", "--seed=42"])

    config.width.should eq(90)
    config.height.should eq(45)
  end

  it "uses the braille size when auto detection falls back to braille" do
    keys = %w[TERM LC_TERMINAL TERM_PROGRAM KITTY_WINDOW_ID WEZTERM_EXECUTABLE GHOSTTY_RESOURCES_DIR]
    previous = keys.to_h { |key| {key, ENV[key]?} }
    keys.each { |key| ENV.delete(key) }

    config = Orbits::CLI.parse_config(["--seed=42"])

    config.width.should eq(120)
    config.height.should eq(120)
  ensure
    previous.try &.each do |key, value|
      if value
        ENV[key] = value
      else
        ENV.delete(key)
      end
    end
  end

  it "keeps default randomization when only common options are set" do
    config = Orbits::CLI.parse_config(["clifford", "--points=2K"])

    config.params.should_not eq(Orbits::AttractorKind::Clifford.default_params)
    config.points.should eq(2_000)
  end

  it "uses seeded random selection deterministically" do
    first = Orbits::CLI.parse_config(["--seed=42"])
    second = Orbits::CLI.parse_config(["--seed=42"])

    first.attractor.should eq(second.attractor)
    first.colormap.should eq(second.colormap)
    first.params.should eq(second.params)
    first.window.should eq(second.window)
    first.seed.should eq(42_u64)
  end

  it "exposes an automatically generated seed that reproduces an unseeded draw" do
    first = Orbits::CLI.parse_config([] of String)
    seed = first.seed.should_not be_nil
    second = Orbits::CLI.parse_config(["--seed=#{seed}"])

    second.attractor.should eq(first.attractor)
    second.colormap.should eq(first.colormap)
    second.params.should eq(first.params)
    second.window.should eq(first.window)
  end

  it "rejects the removed random option" do
    expect_raises(ArgumentError, "unknown argument: --random") do
      Orbits::CLI.parse_config(["--random"])
    end
  end

  it "keeps attractor defaults outside coefficients when randomizing parameters" do
    config = Orbits::CLI.parse_config(["ikeda", "--seed=42"])

    config.params.x0.should eq(0.1)
    config.params.y0.should eq(0.1)
    config.params.theta.should be_nil
    config.params.dtheta.should eq(0.0)
  end

  it "keeps user-selected non-coefficient parameters when randomizing" do
    config = Orbits::CLI.parse_config([
      "clifford",
      "--xy=0.25,-0.5",
      "--theta=0.1",
      "--dtheta=0.01",
      "--seed=42",
    ])

    config.params.x0.should eq(0.25)
    config.params.y0.should eq(-0.5)
    config.params.theta.should eq(0.1)
    config.params.dtheta.should eq(0.01)
  end

  it "draws only the parameters each attractor uses" do
    ikeda = Orbits::CLI.parse_config(["ikeda", "--seed=42"]).params
    ikeda.a.should be >= 0.6
    ikeda.a.should be <= 0.95
    ikeda.b.should eq(0.0) # unused by the Ikeda map, left at default

    hopalong = Orbits::CLI.parse_config(["hopalong", "--seed=42"]).params
    hopalong.d.should eq(0.0) # unused by the Hopalong map, left at default
  end

  it "auto-fits the window when randomizing without an explicit window" do
    config = Orbits::CLI.parse_config(["clifford", "--seed=42"])

    config.window.should_not eq(Orbits::AttractorKind::Clifford.default_window)
    config.window_explicit?.should be_false
  end

  it "keeps an explicit window when randomizing" do
    config = Orbits::CLI.parse_config(["clifford", "--seed=42", "--window=-1,1,-1,1"])

    config.window.should eq(Orbits::Window.new(-1.0, 1.0, -1.0, 1.0))
    config.window_explicit?.should be_true
  end

  it "prints a reproduce command with non-default render-shaping options" do
    output = IO::Memory.new
    error = IO::Memory.new
    path = File.tempname("orbits-cli-spec", ".png")
    begin
      status = Orbits::CLI.run(
        [
          "clifford",
          "--seed=42",
          "--print-params",
          "--points=1",
          "--orbits=4",
          "--size=1x1",
          "--xform=log",
          "--output=#{path}",
        ],
        output,
        error
      )

      status.should eq(0)
      printed = error.to_s
      printed.should contain("reproduce ->")
      printed.should contain("seed      42")
      printed.should contain("--seed 42")
      printed.should contain("--orbits 4")
      printed.should contain("--xform log")
      printed.should contain("--colormap ")
      {% if flag?(:win32) %}
        printed.should contain("orbits clifford --abcd")
        printed.should_not contain(" \\\n")
        printed.should_not contain(" ^\n")
        printed.should_not contain(" `\n")
      {% else %}
        printed.should contain(" \\\n")
      {% end %}
    ensure
      File.delete(path) if File.exists?(path)
    end
  end

  it "writes text protocol output files" do
    output = IO::Memory.new
    error = IO::Memory.new
    path = File.tempname("orbits-cli-text-spec", ".txt")
    begin
      status = Orbits::CLI.run(
        [
          "dejong",
          "--points=1",
          "--size=1x1",
          "--protocol=shades",
          "--output=#{path}",
          "--quiet",
        ],
        output,
        error
      )

      status.should eq(0)
      contents = File.read(path)
      contents.should_not start_with("\x89PNG")
      contents.should end_with("\n")
      contents.size.should be > 0
    ensure
      File.delete(path) if File.exists?(path)
    end
  end

  it "falls back to one static frame when animation stdout is redirected" do
    output = IO::Memory.new
    error = IO::Memory.new
    status = Orbits::CLI.run(
      [
        "clifford",
        "--seed=42",
        "--animate=reveal",
        "--points=10",
        "--size=4x4",
        "--protocol=shades",
        "--quiet",
      ],
      output,
      error
    )

    status.should eq(0)
    output.to_s.should_not contain("\e[?1049h")
    output.to_s.scan(/\e\[H/).size.should eq(0)
    output.to_s.should end_with("\n")
  end

  it "reports an automatically reduced morph amount" do
    output = TTYMemory.new
    error = TTYMemory.new

    status = Orbits::CLI.run(
      %w[dejong --seed=7 --animate=morph --points=12 --fps=12 --duration=1 --size=8x8 --protocol=shades --print-params],
      output,
      error
    )

    status.should eq(0)
    error.to_s.should contain("morph amount adjusted from 1.0 to 0.125")
  end
end
