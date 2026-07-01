require "../spec_helper"

describe Orbits::Xforms do
  it "handles empty bins" do
    bins = [] of UInt32
    Orbits::Xforms.apply(bins, Orbits::Xform::Linear).to_a.should eq([] of UInt8)
    Orbits::Xforms.apply(bins, Orbits::Xform::Log).to_a.should eq([] of UInt8)
    Orbits::Xforms.apply(bins, Orbits::Xform::Cubic).to_a.should eq([] of UInt8)
    Orbits::Xforms.apply(bins, Orbits::Xform::Equalized).to_a.should eq([] of UInt8)
  end

  it "applies boolean transform" do
    Orbits::Xforms.apply([0_u32, 1_u32, 3_u32], Orbits::Xform::Boolean).to_a.should eq([0_u8, 255_u8, 255_u8])
  end

  it "applies linear transform" do
    Orbits::Xforms.apply([0_u32, 5_u32, 10_u32], Orbits::Xform::Linear).to_a.should eq([0_u8, 127_u8, 255_u8])
  end

  it "applies cubic transform from the minimum populated value" do
    Orbits::Xforms.apply([10_u32, 15_u32, 20_u32], Orbits::Xform::Cubic).to_a.should eq([0_u8, 207_u8, 255_u8])
  end

  it "applies equalized transform deterministically" do
    bins = [0_u32, 0_u32, 1_u32, 2_u32, 2_u32, 2_u32]
    Orbits::Xforms.apply(bins, Orbits::Xform::Equalized).to_a.should eq([0_u8, 0_u8, 63_u8, 255_u8, 255_u8, 255_u8])
  end

  it "equalizes sparse high-density bins without indexing by density value" do
    bins = [0_u32, UInt32::MAX]
    Orbits::Xforms.apply(bins, Orbits::Xform::Equalized).to_a.should eq([0_u8, 255_u8])
  end
end
