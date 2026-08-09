require "../spec_helper"

describe Orbits::Animator do
  it "plays the requested reveal frames and returns the completed render" do
    output = IO::Memory.new
    config = Orbits::Config.new(
      points: 10,
      width: 4,
      height: 4,
      protocol: TermImage::Protocol::Shades,
      animation: Orbits::AnimationMode::Reveal,
      fps: 2,
      duration: 1.0
    )

    image = Orbits::Animator.new(config, output, pace: false).render

    image.indices.should eq(Orbits::Renderer.new(config).render.indices)
    output.to_s.scan(/\x1b\[H/).size.should eq(3) # session start + 2 frames
    output.to_s.should end_with("\e[?25h\e[?1049l")
  end

  it "plays trail and morph as distinct multi-frame modes" do
    [Orbits::AnimationMode::Trail, Orbits::AnimationMode::Morph].each do |mode|
      output = IO::Memory.new
      config = Orbits::Config.new(
        points: 20,
        width: 8,
        height: 8,
        protocol: TermImage::Protocol::Shades,
        animation: mode,
        fps: 2,
        duration: 1.0,
        trail_points: 5
      )

      image = Orbits::Animator.new(config, output, pace: false).render

      image.indices.size.should eq(64)
      output.to_s.scan(/\x1b\[H/).size.should eq(3)
      output.to_s.should end_with("\e[?25h\e[?1049l")
    end
  end

  it "uses the full point budget for every independent morph frame" do
    output = IO::Memory.new
    config = Orbits::Config.new(
      points: 1_000,
      width: 32,
      height: 32,
      protocol: TermImage::Protocol::Shades,
      animation: Orbits::AnimationMode::Morph,
      fps: 2,
      duration: 1.0
    )

    actual = Orbits::Animator.new(config, output, pace: false).render
    planner = Orbits::MorphPlanner.new(config, 2)
    final_config = config.dup
    final_config.animation = nil
    final_config.window = planner.window
    final_config.params = planner.params_for(1)

    actual.indices.should eq(Orbits::Renderer.new(final_config).render.indices)
  end

  it "reuses one parallel execution context across all morph frames" do
    before = 0
    Fiber::ExecutionContext.each { before += 1 }
    config = Orbits::Config.new(
      points: 40,
      orbits: 4,
      width: 8,
      height: 8,
      protocol: TermImage::Protocol::Shades,
      animation: Orbits::AnimationMode::Morph,
      fps: 10,
      duration: 3.0
    )

    Orbits::Animator.new(config, IO::Memory.new, pace: false).render

    after = 0
    Fiber::ExecutionContext.each { after += 1 }
    (after - before).should eq(1)
  end
end
