module Orbits
  class Animator
    getter effective_morph_amount : Float64?

    def initialize(@config : Config, @output : IO = STDOUT, @pace = true)
      @termination = TerminationMonitor.new
      @effective_morph_amount = nil
    end

    def interrupted? : Bool
      @termination.interrupted?
    end

    # Plays the requested animation and returns the completed image so the CLI
    # can leave a normal, persistent final render after closing the alt screen.
    def render : TermImage::Indexed
      mode = @config.animation
      raise ArgumentError.new("animation mode is required") unless mode

      @termination.around do
        case mode
        in AnimationMode::Reveal
          render_reveal
        in AnimationMode::Trail
          render_trail
        in AnimationMode::Morph
          render_morph
        end
      end
    end

    private def render_reveal : TermImage::Indexed
      render_progressively(ProgressiveRenderer.new(@config))
    end

    private def render_trail : TermImage::Indexed
      render_progressively(TrailRenderer.new(@config))
    end

    private def render_progressively(renderer : ProgressiveRenderer | TrailRenderer) : TermImage::Indexed
      play do |frame, frame_count|
        renderer.add_points(points_for_frame(frame, frame_count))
        renderer.render
      end
    end

    # Each morph frame is an independent static attractor, so points are a
    # per-frame quality budget. The planner computes one window for the full
    # loop, avoiding both camera movement and frames escaping the viewport.
    private def render_morph : TermImage::Indexed
      frame_config = @config.dup
      frame_config.animation = nil
      frame_config.points = @config.points
      frame_count = animation_frame_count
      planner = MorphPlanner.new(@config, frame_count)
      @effective_morph_amount = planner.amount
      frame_config.window = planner.window
      context = morph_execution_context
      play do |frame, _|
        frame_config.params = planner.params_for(frame)
        Renderer.new(frame_config, context).render
      end
    end

    private def morph_execution_context : Fiber::ExecutionContext::Parallel?
      return if @config.orbits == 1

      workers = Math.min(@config.orbits, System.cpu_count.to_i)
      Fiber::ExecutionContext::Parallel.new("orbits-morph", workers)
    end

    private def play(& : Int32, Int32 -> TermImage::Indexed) : TermImage::Indexed
      writer = TermImage::FrameWriter.new(@config.protocol, @output)
      frame_count = animation_frame_count
      deadline = Time.instant
      image : TermImage::Indexed? = nil

      writer.start
      frame_count.times do |frame|
        break if interrupted? && image
        image = yield frame, frame_count
        writer.write(image)
        break if interrupted?
        deadline = pace_frame(frame, frame_count, deadline)
      end
      image || raise "animation produced no frames"
    ensure
      writer.try &.finish
    end

    private def points_for_frame(frame : Int32, frame_count : Int32) : Int64
      base = @config.points // frame_count
      remainder = @config.points % frame_count
      base + (frame.to_i64 < remainder ? 1_i64 : 0_i64)
    end

    private def pace_frame(frame : Int32, frame_count : Int32, deadline : Time::Instant) : Time::Instant
      return deadline if frame == frame_count - 1 || !@pace

      deadline += (1.0 / @config.fps).seconds
      remaining = deadline - Time.instant
      sleep remaining if remaining.positive?
      deadline
    end

    private def animation_frame_count : Int32
      requested_float = @config.fps.to_f64 * @config.duration
      if requested_float >= Int32::MAX
        return Math.min(@config.points, Int32::MAX.to_i64).to_i
      end

      requested = requested_float.round.to_i64
      Math.min(Math.max(requested, 1_i64), @config.points).to_i
    end
  end
end
