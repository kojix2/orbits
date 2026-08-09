require "../spec_helper"

describe Orbits::Raster do
  it "preserves saturated additions until their matching removal" do
    raster = Orbits::Raster.new(1, 1, Orbits::Window.new(-1.0, 1.0, -1.0, 1.0))
    raster.bins[0] = UInt32::MAX

    index = raster.add(0.0, 0.0).should_not be_nil
    raster.remove(index)
    raster.bins[0].should eq(UInt32::MAX)

    raster.remove(index)
    raster.bins[0].should eq(UInt32::MAX - 1_u32)
  end

  it "maps world coordinates to GR-like raster bins" do
    raster = Orbits::Raster.new(3, 3, Orbits::Window.new(-1.0, 1.0, -1.0, 1.0))
    raster.add(-1.0, -1.0)
    raster.add(0.0, 0.0)
    raster.add(1.0, 1.0)

    raster.bins[6].should eq(1) # lower-left world coordinate
    raster.bins[4].should eq(1)
    raster.bins[2].should eq(1) # upper-right world coordinate
  end

  it "ignores points outside the window" do
    raster = Orbits::Raster.new(3, 3, Orbits::Window.default)
    raster.add(99.0, 0.0)
    raster.bins.sum.should eq(0)
  end

  it "returns and removes mapped pixel indices" do
    raster = Orbits::Raster.new(3, 3, Orbits::Window.default)
    index = raster.add(0.0, 0.0).should_not be_nil
    raster.add(0.0, 0.0)

    raster.bins[index].should eq(2)
    raster.remove(index)
    raster.bins[index].should eq(1)
  end

  it "merges compatible rasters with saturating bin counts" do
    first = Orbits::Raster.new(3, 3, Orbits::Window.default)
    second = Orbits::Raster.new(3, 3, Orbits::Window.default)

    first.add(0.0, 0.0)
    second.add(0.0, 0.0)
    first.merge!(second)

    first.bins[4].should eq(2)
  end

  it "rejects incompatible raster merges" do
    first = Orbits::Raster.new(3, 3, Orbits::Window.default)
    second = Orbits::Raster.new(4, 3, Orbits::Window.default)

    expect_raises(ArgumentError, "raster shape mismatch") do
      first.merge!(second)
    end
  end
end
