require "../spec_helper"

describe Orbits::AttractorKind do
  it "reports valid attractor names for unknown values" do
    expect_raises(ArgumentError, "unknown attractor: nope (choose from clifford, dejong, ikeda, hopalong)") do
      Orbits::AttractorKind.parse("nope")
    end
  end
end

describe Orbits::Renderer do
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
end
