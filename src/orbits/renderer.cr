module Orbits
  class Renderer
    def initialize(@config : Config,
                   @execution_context : Fiber::ExecutionContext::Parallel? = nil)
    end

    def render : TermImage::Indexed
      raster = render_density
      TermImage::Indexed.new(
        @config.width,
        @config.height,
        raster.transform(@config.xform),
        @config.colormap.palette,
        # Density 0 is empty space in renderer output, so it is safe to expose
        # it as transparent for RGBA-based output protocols.
        0_u8
      )
    end

    private def render_density : Raster
      return render_orbit(@config.params, @config.points) if @config.orbits == 1

      render_orbits_parallel
    end

    private def render_orbits_parallel : Raster
      orbits = @config.orbits
      worker_count = Math.min(orbits, System.cpu_count.to_i)
      context = @execution_context || Fiber::ExecutionContext::Parallel.new("orbits", worker_count)
      results = Channel(Raster | Exception).new(orbits)

      orbits.times do |i|
        params = OrbitSeeds.params(@config, i)
        points = points_for_orbit(i)
        context.spawn do
          results.send(render_orbit(params, points))
        rescue ex : Exception
          results.send(ex)
        end
      end

      raster = Raster.new(@config.width, @config.height, @config.window)
      error : Exception? = nil
      orbits.times do
        case result = results.receive
        in Raster
          raster.merge!(result)
        in Exception
          error ||= result
        end
      end

      raise error if error
      raster
    end

    private def render_orbit(params : Params, points : Int64) : Raster
      raster = Raster.new(@config.width, @config.height, @config.window)
      generator = Generator.new(@config.attractor, params)
      generator.each_point(points) do |x, y|
        raster.add(x, y)
      end
      raster
    end

    private def points_for_orbit(index : Int32) : Int64
      orbits = @config.orbits.to_i64
      base = @config.points // orbits
      remainder = @config.points % orbits
      base + (index.to_i64 < remainder ? 1_i64 : 0_i64)
    end
  end
end
