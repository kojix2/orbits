require "../spec_helper"

describe Orbits::Generator do
  it "generates deterministic points" do
    params = Orbits::Params.new(1.5, -1.8, 1.6, 0.9)
    points = [] of {Float64, Float64}
    Orbits::Generator.new(params).each_point(3) do |x, y|
      points << {x, y}
    end

    points.size.should eq(3)
    points[0][0].should be_close(1.6, 1e-12)
    points[0][1].should be_close(0.9, 1e-12)
  end

  it "generates De Jong points" do
    params = Orbits::Params.new(1.4, -2.3, 2.4, -2.1)
    points = [] of {Float64, Float64}
    Orbits::Generator.new(Orbits::AttractorKind::DeJong, params).each_point(1) do |x, y|
      points << {x, y}
    end

    points[0][0].should be_close(-1.0, 1e-12)
    points[0][1].should be_close(-1.0, 1e-12)
  end

  it "generates Ikeda and Hopalong points" do
    [Orbits::AttractorKind::Ikeda, Orbits::AttractorKind::Hopalong].each do |kind|
      points = [] of {Float64, Float64}
      Orbits::Generator.new(kind, kind.default_params).each_point(1) do |x, y|
        points << {x, y}
      end

      points.size.should eq(1)
    end
  end

  it "exposes a summary and multi-line formula for every attractor" do
    [
      Orbits::AttractorKind::Clifford,
      Orbits::AttractorKind::DeJong,
      Orbits::AttractorKind::Ikeda,
      Orbits::AttractorKind::Hopalong,
    ].each do |kind|
      kind.summary.should_not be_empty
      kind.formula.should_not be_empty
      kind.formula.each(&.should_not(be_empty))
    end
  end

  it "uses an Ikeda default that fills the default window" do
    kind = Orbits::AttractorKind::Ikeda
    params = kind.default_params
    window = kind.default_window
    raster = Orbits::Raster.new(128, 128, window)

    Orbits::Generator.new(kind, params).each_point(50_000) do |x, y|
      raster.add(x, y)
    end

    params.a.should eq(0.9)
    window.xmin.should eq(-0.5)
    window.xmax.should eq(1.7)
    window.ymin.should eq(-2.2)
    window.ymax.should eq(1.0)
    raster.bins.count { |v| v > 0 }.should be > 1_000
  end
end
