module Orbits
  # Converts process termination requests into a flag that animation loops can
  # observe, while preserving any signal handlers installed by the caller.
  class TerminationMonitor
    {% unless flag?(:win32) %}
      @previous_int_handler : Proc(Signal, Nil)?
      @previous_hup_handler : Proc(Signal, Nil)?
      @previous_term_handler : Proc(Signal, Nil)?
    {% end %}

    def initialize
      @interrupted = Atomic(Bool).new(false)
    end

    def interrupted? : Bool
      @interrupted.get
    end

    def around(&)
      @interrupted.set(false)
      install
      begin
        yield
      ensure
        restore
      end
    end

    private def install : Nil
      {% unless flag?(:win32) %}
        @previous_int_handler = Signal::INT.trap_handler?
        @previous_hup_handler = Signal::HUP.trap_handler?
        @previous_term_handler = Signal::TERM.trap_handler?
      {% end %}
      Process.on_terminate { @interrupted.set(true) }
    end

    private def restore : Nil
      {% if flag?(:win32) %}
        Process.restore_interrupts!
      {% else %}
        restore_signal(Signal::INT, @previous_int_handler)
        restore_signal(Signal::HUP, @previous_hup_handler)
        restore_signal(Signal::TERM, @previous_term_handler)
      {% end %}
    end

    {% unless flag?(:win32) %}
      private def restore_signal(signal : Signal, handler : Proc(Signal, Nil)?) : Nil
        if handler
          signal.trap { |received| handler.call(received) }
        else
          signal.reset
        end
      end
    {% end %}
  end
end
