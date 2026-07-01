module Orbits
  # Picks random parameters that are likely to render into an interesting
  # image, and auto-fits a window to them.
  #
  # Plain uniform sampling wastes most draws: an empirical survey (see
  # bench/random_survey.cr) showed ~40% of Clifford/De Jong draws over the old
  # [-2,2] range collapse to a point or line, and ~half of Ikeda draws over
  # that range diverge. The fix, in order of impact measured there:
  #
  #   1. per-attractor coefficient ranges (only the params each map uses)
  #   2. reject diverged / degenerate / near-empty draws via a short trial
  #   3. auto-fit the window to the accepted orbit's bounding box
  #
  # This deliberately stays simple: no Lyapunov test, no best-of-N. The trial
  # is cheap relative to a full render, so a rejection loop costs little.
  module RandomParams
    extend self

    # Which coefficients to draw for an attractor, and over what range. A nil
    # field is left at the attractor's default — either the map ignores that
    # coefficient, or it is not meant to vary. This is sampling policy, tuned
    # from bench/random_survey.cr, so it lives here with random selection
    # rather than in the attractor's mathematical definition.
    private record CoefficientRanges,
      a : Range(Float64, Float64)? = nil,
      b : Range(Float64, Float64)? = nil,
      c : Range(Float64, Float64)? = nil,
      d : Range(Float64, Float64)? = nil

    # Per-attractor draw ranges, all in one place. `case ... in` stays
    # exhaustive, so adding an attractor won't compile until its ranges are set.
    private def coefficient_ranges(kind : AttractorKind) : CoefficientRanges
      case kind
      in .clifford?, .de_jong?
        CoefficientRanges.new(a: -3.0..3.0, b: -3.0..3.0, c: -3.0..3.0, d: -3.0..3.0)
      in .ikeda?
        CoefficientRanges.new(a: 0.6..0.95) # only u = a is used
      in .hopalong?
        # d is unused; the auto-fitted window absorbs Hopalong's wide scale.
        CoefficientRanges.new(a: -2.0..2.0, b: -2.0..2.0, c: -2.0..2.0)
      end
    end

    BURN_IN_ITERATIONS =  1_000 # discarded before measuring
    SAMPLE_SIZE        = 20_000 # measured iterations per trial
    GRID_SIZE          =    128 # occupancy raster resolution
    DIVERGENCE_LIMIT   =  1.0e6 # maximum absolute coordinate
    MINIMUM_SPAN       = 1.0e-4 # smaller bounds represent a point or line
    MINIMUM_OCCUPANCY  =   0.02 # rejects thin, near-empty orbits
    MAXIMUM_ATTEMPTS   =    200 # falls back to the best candidate afterward
    WINDOW_PADDING     =   0.05 # margin around fitted bounds

    # Returns randomized params plus a window fitted to them. Draws are driven
    # entirely by `rng`, so a seeded rng gives reproducible results. The base
    # params preserve user-selected non-coefficient fields such as x0/y0/theta.
    def choose(kind : AttractorKind, base : Params, rng : Random) : {Params, Window}
      best : {Params, Window}? = nil
      best_occupancy = -1.0

      MAXIMUM_ATTEMPTS.times do
        params = draw_params(kind, base, rng)
        result = evaluate(kind, params)
        next unless result # diverged or degenerate

        occupancy_ratio, window = result
        return {params, window} if occupancy_ratio >= MINIMUM_OCCUPANCY
        if occupancy_ratio > best_occupancy
          best_occupancy = occupancy_ratio
          best = {params, window}
        end
      end

      best || {base, kind.default_window}
    end

    # Draw the coefficients selected for this attractor, leaving
    # the rest — including x0/y0/theta — at the current params.
    private def draw_params(kind : AttractorKind, base : Params, rng : Random) : Params
      params = base.dup
      ranges = coefficient_ranges(kind)
      if range = ranges.a
        params.a = rng.rand(range)
      end
      if range = ranges.b
        params.b = rng.rand(range)
      end
      if range = ranges.c
        params.c = rng.rand(range)
      end
      if range = ranges.d
        params.d = rng.rand(range)
      end
      params
    end

    # Runs a short orbit and returns {occupancy, fitted window}, or nil if the
    # orbit escaped or collapsed. Uses Generator so theta modulation (if any)
    # is applied exactly as during the real render.
    private def evaluate(kind : AttractorKind, params : Params) : {Float64, Window}?
      x_coordinates = Array(Float64).new(SAMPLE_SIZE)
      y_coordinates = Array(Float64).new(SAMPLE_SIZE)
      escaped = false
      iteration = 0
      Generator.new(kind, params).each_point((BURN_IN_ITERATIONS + SAMPLE_SIZE).to_i64) do |x, y|
        unless x.finite? && y.finite? && x.abs < DIVERGENCE_LIMIT && y.abs < DIVERGENCE_LIMIT
          escaped = true
          break
        end
        if iteration >= BURN_IN_ITERATIONS
          x_coordinates << x
          y_coordinates << y
        end
        iteration += 1
      end
      return if escaped || x_coordinates.empty?

      x_min, x_max = percentile_bounds(x_coordinates)
      y_min, y_max = percentile_bounds(y_coordinates)
      x_span = x_max - x_min
      y_span = y_max - y_min
      return if x_span < MINIMUM_SPAN || y_span < MINIMUM_SPAN

      occupancy_ratio = occupancy(x_coordinates, y_coordinates, x_min, y_min, x_span, y_span)

      x_margin = x_span * WINDOW_PADDING
      y_margin = y_span * WINDOW_PADDING
      window = Window.new(x_min - x_margin, x_max + x_margin, y_min - y_margin, y_max + y_margin)
      {occupancy_ratio, window}
    end

    private def occupancy(x_coordinates : Array(Float64), y_coordinates : Array(Float64),
                          x_min : Float64, y_min : Float64,
                          x_span : Float64, y_span : Float64) : Float64
      occupied_cells = Set(Int32).new
      x_coordinates.each_with_index do |x, index|
        column = ((x - x_min) / x_span * (GRID_SIZE - 1)).to_i
        row = ((y_coordinates[index] - y_min) / y_span * (GRID_SIZE - 1)).to_i
        if column >= 0 && column < GRID_SIZE && row >= 0 && row < GRID_SIZE
          occupied_cells << row * GRID_SIZE + column
        end
      end
      occupied_cells.size.to_f / (GRID_SIZE * GRID_SIZE)
    end

    # 0.5..99.5 percentile clip, so a few stray points can't blow up the window.
    private def percentile_bounds(values : Array(Float64)) : {Float64, Float64}
      sorted = values.sort
      {sorted[(sorted.size * 0.005).to_i], sorted[(sorted.size * 0.995).to_i]}
    end
  end
end
