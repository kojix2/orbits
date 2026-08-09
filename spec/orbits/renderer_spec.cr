require "../spec_helper"

describe Orbits::AttractorKind do
  it "reports valid attractor names for unknown values" do
    expect_raises(ArgumentError, "unknown attractor: nope (choose from clifford, dejong, ikeda, hopalong)") do
      Orbits::AttractorKind.parse("nope")
    end
  end
end

describe Orbits::Renderer do
  it "creates evenly spaced nearby orbit seeds" do
    config = Orbits::Config.new(orbits: 4)
    seeds = Orbits::OrbitSeeds.build(config)

    seeds.size.should eq(4)
    Orbits::OrbitSeeds.params(config, 0).x0.should be_close(config.params.x0 + 1e-6, 1e-12)
    Orbits::OrbitSeeds.params(config, 1).y0.should be_close(config.params.y0 + 1e-6, 1e-12)
  end

  it "renders multiple orbits into one indexed image" do
    config = Orbits::Config.new(points: 64, orbits: 4, width: 16, height: 12)
    image = Orbits::Renderer.new(config).render

    image.width.should eq(16)
    image.height.should eq(12)
    image.indices.size.should eq(16 * 12)
    image.transparent_index.should eq(0_u8)
  end

  it "renders a non-Clifford attractor" do
    config = Orbits::Config.new(
      attractor: Orbits::AttractorKind::DeJong,
      points: 64,
      width: 16,
      height: 12
    )
    image = Orbits::Renderer.new(config).render

    image.width.should eq(16)
    image.height.should eq(12)
  end

  it "builds the same image incrementally across animation frames" do
    config = Orbits::Config.new(points: 101, orbits: 4, width: 16, height: 12)
    progressive = Orbits::ProgressiveRenderer.new(config)
    progressive.add_points(37)
    progressive.add_points(64)

    progressive.render.indices.should eq(Orbits::Renderer.new(config).render.indices)
    progressive.rendered_points.should eq(101)
  end

  it "limits a moving trail to its configured point count" do
    config = Orbits::Config.new(
      points: 20,
      width: 32,
      height: 32,
      window: Orbits::Window.new(-10.0, 10.0, -10.0, 10.0),
      trail_points: 5
    )
    trail = Orbits::TrailRenderer.new(config)
    trail.add_points(20)

    trail.active_points.should eq(5)
    trail.render.indices.max.should eq(255_u8) # visible head marker
  end

  it "scales the trail head marker for a graphics-sized raster" do
    config = Orbits::Config.new(
      points: 1,
      width: 640,
      height: 640,
      window: Orbits::Window.new(-10.0, 10.0, -10.0, 10.0),
      trail_points: 1
    )
    trail = Orbits::TrailRenderer.new(config)
    trail.add_points(1)

    trail.render.indices.count { |index| index >= Orbits::TrailRenderer::HEAD_INDEX_MIN }.should be > 100
  end
end
