module Orbits
  class Renderer
    def initialize(@config : Config)
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

      render_orbits
    end

    private def render_orbits : Raster
      {% if flag?(:execution_context) %}
        render_orbits_parallel
      {% else %}
        raster = Raster.new(@config.width, @config.height, @config.window)
        @config.orbits.times do |i|
          raster.merge!(render_orbit(orbit_params(i), points_for_orbit(i)))
        end
        raster
      {% end %}
    end

    {% if flag?(:execution_context) %}
      private def render_orbits_parallel : Raster
        orbits = @config.orbits
        worker_count = Math.min(orbits, System.cpu_count.to_i)
        context = Fiber::ExecutionContext::Parallel.new("orbits", worker_count)
        results = Channel(Raster | Exception).new(orbits)

        orbits.times do |i|
          params = orbit_params(i)
          points = points_for_orbit(i)
          context.spawn do
            begin
              results.send(render_orbit(params, points))
            rescue ex : Exception
              results.send(ex)
            end
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
    {% end %}

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

    private def orbit_params(index : Int32) : Params
      return @config.params if @config.orbits == 1

      angle = 2.0 * Math::PI * index.to_f64 / @config.orbits
      radius = 1.0e-6
      x = @config.params.x0 + Math.cos(angle) * radius
      y = @config.params.y0 + Math.sin(angle) * radius
      @config.params.with_xy(x, y)
    end
  end
end
