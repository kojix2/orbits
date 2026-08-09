require "../spec_helper"

describe Orbits::ParameterMotion do
  it "follows a closed parameter path without mutating its base" do
    base = Orbits::AttractorKind::Clifford.default_params
    original = base.dup
    start = Orbits::ParameterMotion.at(Orbits::AttractorKind::Clifford, base, 0.0, 1.0)
    finish = Orbits::ParameterMotion.at(Orbits::AttractorKind::Clifford, base, 2.0 * Math::PI, 1.0)

    start.a.should be_close(finish.a, 1e-12)
    start.b.should be_close(finish.b, 1e-12)
    start.c.should be_close(finish.c, 1e-12)
    start.d.should be_close(finish.d, 1e-12)
    base.should eq(original)
  end

  it "keeps every attractor inside its supported coefficient range" do
    Orbits::AttractorKind.values.each do |kind|
      params = Orbits::ParameterMotion.at(kind, kind.default_params, 1.25, 100.0)
      case kind
      in .clifford?, .de_jong?
        [params.a, params.b, params.c, params.d].each do |value|
          value.should be >= -3.0
          value.should be <= 3.0
        end
      in .ikeda?
        params.a.should be >= 0.6
        params.a.should be <= 0.95
      in .hopalong?
        [params.a, params.b, params.c].each do |value|
          value.should be >= -2.0
          value.should be <= 2.0
        end
      end
    end
  end

  it "keeps an Ikeda morph at or below its stable base value" do
    base = Orbits::AttractorKind::Ikeda.default_params
    base.a = 0.9

    values = (0..24).map do |frame|
      Orbits::ParameterMotion.at(
        Orbits::AttractorKind::Ikeda,
        base,
        2.0 * Math::PI * frame / 24,
        1.5
      ).a
    end

    values.max.should eq(base.a)
    values.min.should be < base.a
    values.first.should be_close(values.last, 1e-12)
  end

  it "plans one fixed window around the complete morph loop" do
    config = Orbits::Config.new(
      attractor: Orbits::AttractorKind::Ikeda,
      params: Orbits::Params.new(0.9, 0.0, 0.0, 0.0, x0: 0.1, y0: 0.1),
      animation: Orbits::AnimationMode::Morph,
      morph_amount: 1.5
    )

    planner = Orbits::MorphPlanner.new(config, 12)

    planner.amount.should be > 0.0
    planner.minimum_occupancy.should be > 0.1
    planner.window.xmin.should be <= config.window.xmin
    planner.window.xmax.should be >= config.window.xmax
    (0...60).all? { |frame| planner.params_for(frame).a <= config.params.a }.should be_true
  end

  it "preserves an explicitly selected morph window exactly" do
    window = Orbits::Window.new(-2.0, 2.0, -2.0, 2.0)
    config = Orbits::Config.new(
      attractor: Orbits::AttractorKind::Ikeda,
      params: Orbits::Params.new(0.9, 0.0, 0.0, 0.0, x0: 0.1, y0: 0.1),
      window: window,
      animation: Orbits::AnimationMode::Morph
    )

    Orbits::MorphPlanner.new(config, 12).window.should eq(window)
  end
end
