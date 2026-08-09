module Orbits
  # Chooses a stable coefficient loop and one fixed window that contains it.
  # A short preview is substantially cheaper than a rendered frame and avoids
  # camera movement, escaped frames, and parameter paths that collapse.
  class MorphPlanner
    WINDOW_PHASES          =     60
    BURN_IN_POINTS         = 10_000
    SAMPLE_POINTS          =  5_000
    GRID_SIZE              =     64
    DIVERGENCE_LIMIT       =  1.0e6
    MINIMUM_SPAN           = 1.0e-6
    MINIMUM_OCCUPANCY      =  0.002
    MIN_RELATIVE_OCCUPANCY =    0.3
    MIN_RELATIVE_SPAN      =   0.08
    MAX_AMOUNT_ATTEMPTS    =      5
    WINDOW_PADDING         =   0.05

    private record PhaseBounds,
      xmin : Float64,
      xmax : Float64,
      ymin : Float64,
      ymax : Float64,
      occupancy : Float64,
      xs : Array(Float64),
      ys : Array(Float64)

    getter window : Window
    getter amount : Float64
    getter minimum_occupancy : Float64
    getter minimum_visibility : Float64

    def initialize(@config : Config, @frame_count : Int32)
      amount = @config.morph_amount
      selected : Array(PhaseBounds)? = nil

      MAX_AMOUNT_ATTEMPTS.times do
        candidate = analyze(amount)
        if candidate && coherent?(candidate)
          selected = candidate
          break
        end
        amount *= 0.5
      end

      unless selected
        amount = 0.0
        selected = analyze(amount)
      end

      bounds = selected || [] of PhaseBounds
      @amount = amount
      @minimum_occupancy = bounds.empty? ? 0.0 : bounds.min_of(&.occupancy)
      @window = envelope(bounds)
      @minimum_visibility = if bounds.empty?
                              0.0
                            else
                              bounds.min_of { |item| visibility(item.xs, item.ys, @window) }
                            end
    end

    def params_for(frame : Int32) : Params
      ParameterMotion.at(@config.attractor, @config.params, phase(frame, @frame_count), @amount)
    end

    private def analyze(amount : Float64) : Array(PhaseBounds)?
      count = Math.min(Math.max(@frame_count, 1), WINDOW_PHASES)
      Array(PhaseBounds).new(count) do |index|
        params = ParameterMotion.at(@config.attractor, @config.params, phase(index, count), amount)
        analyze_phase(params) || return
      end
    end

    private def analyze_phase(params : Params) : PhaseBounds?
      xs = Array(Float64).new(SAMPLE_POINTS)
      ys = Array(Float64).new(SAMPLE_POINTS)
      iteration = 0

      Generator.new(@config.attractor, params).each_point((BURN_IN_POINTS + SAMPLE_POINTS).to_i64) do |x, y|
        return unless x.finite? && y.finite?
        return if x.abs >= DIVERGENCE_LIMIT || y.abs >= DIVERGENCE_LIMIT

        if iteration >= BURN_IN_POINTS
          xs << x
          ys << y
        end
        iteration += 1
      end

      xmin, xmax = percentile_bounds(xs)
      ymin, ymax = percentile_bounds(ys)
      return if xmax - xmin < MINIMUM_SPAN || ymax - ymin < MINIMUM_SPAN

      occupancy = occupancy(xs, ys, xmin, xmax, ymin, ymax)
      PhaseBounds.new(xmin, xmax, ymin, ymax, occupancy, xs, ys)
    end

    private def percentile_bounds(values : Array(Float64)) : {Float64, Float64}
      sorted = values.sort
      low = (sorted.size * 0.01).to_i
      high = (sorted.size * 0.99).to_i.clamp(0, sorted.size - 1)
      {sorted[low], sorted[high]}
    end

    private def occupancy(xs : Array(Float64), ys : Array(Float64),
                          xmin : Float64, xmax : Float64,
                          ymin : Float64, ymax : Float64) : Float64
      occupied = Array(Bool).new(GRID_SIZE * GRID_SIZE, false)
      xscale = (GRID_SIZE - 1) / (xmax - xmin)
      yscale = (GRID_SIZE - 1) / (ymax - ymin)
      count = 0

      xs.each_with_index do |x, index|
        y = ys[index]
        next unless x >= xmin && x <= xmax && y >= ymin && y <= ymax

        column = ((x - xmin) * xscale).to_i.clamp(0, GRID_SIZE - 1)
        row = ((y - ymin) * yscale).to_i.clamp(0, GRID_SIZE - 1)
        cell = row * GRID_SIZE + column
        unless occupied[cell]
          occupied[cell] = true
          count += 1
        end
      end

      count.to_f64 / occupied.size
    end

    private def coherent?(bounds : Array(PhaseBounds)) : Bool
      return false if bounds.any? { |item| item.occupancy < MINIMUM_OCCUPANCY }
      occupancies = bounds.map(&.occupancy)
      return false if occupancies.min / occupancies.max < MIN_RELATIVE_OCCUPANCY
      window = envelope(bounds)
      visible_ratios = bounds.map do |item|
        visibility(item.xs, item.ys, window)
      end
      return false if visible_ratios.max.zero?
      return false if visible_ratios.min / visible_ratios.max < MIN_RELATIVE_OCCUPANCY

      xmin = bounds.min_of(&.xmin)
      xmax = bounds.max_of(&.xmax)
      ymin = bounds.min_of(&.ymin)
      ymax = bounds.max_of(&.ymax)
      xspan = xmax - xmin
      yspan = ymax - ymin
      bounds.all? do |item|
        (item.xmax - item.xmin) / xspan >= MIN_RELATIVE_SPAN &&
          (item.ymax - item.ymin) / yspan >= MIN_RELATIVE_SPAN
      end
    end

    private def visibility(xs : Array(Float64), ys : Array(Float64), window : Window) : Float64
      bins = Array(UInt32).new(GRID_SIZE * GRID_SIZE, 0_u32)
      xscale = (GRID_SIZE - 1) / (window.xmax - window.xmin)
      yscale = (GRID_SIZE - 1) / (window.ymax - window.ymin)

      xs.each_with_index do |x, index|
        y = ys[index]
        next unless x >= window.xmin && x <= window.xmax
        next unless y >= window.ymin && y <= window.ymax

        column = ((x - window.xmin) * xscale).to_i.clamp(0, GRID_SIZE - 1)
        row = ((y - window.ymin) * yscale).to_i.clamp(0, GRID_SIZE - 1)
        bins[row * GRID_SIZE + column] &+= 1_u32
      end

      Xforms.apply(bins, @config.xform).count { |value| value > 0 }.to_f64 / bins.size
    end

    private def envelope(bounds : Array(PhaseBounds)) : Window
      return @config.window if bounds.empty? || @config.window_explicit?

      xmin = Math.min(@config.window.xmin, bounds.min_of(&.xmin))
      xmax = Math.max(@config.window.xmax, bounds.max_of(&.xmax))
      ymin = Math.min(@config.window.ymin, bounds.min_of(&.ymin))
      ymax = Math.max(@config.window.ymax, bounds.max_of(&.ymax))
      xmargin = (xmax - xmin) * WINDOW_PADDING
      ymargin = (ymax - ymin) * WINDOW_PADDING
      Window.new(xmin - xmargin, xmax + xmargin, ymin - ymargin, ymax + ymargin)
    end

    private def phase(index : Int32, count : Int32) : Float64
      2.0 * Math::PI * index / Math.max(count, 1)
    end
  end
end
