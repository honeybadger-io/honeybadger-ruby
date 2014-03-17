module Honeybadger
  class Dependency
    class << self
      @@instances = []

      def instances
        @@instances
      end

      def register
        instances << new.tap { |d| d.instance_eval(&Proc.new) }
      end

      def inject!
        instances.each do |dependency|
          dependency.inject! if dependency.ok?
        end
      end

      def reset!
        instances.each(&:reset!)
      end
    end

    def initialize
      @injected     = false
      @requirements = []
      @injections   = []
    end

    def requirement
      @requirements << Proc.new
    end

    def injection
      @injections << Proc.new
    end

    def ok?
      !@injected && @requirements.all?(&:call)
    rescue => e
      Honeybadger.write_verbose_log("Exception caught while verifying dependency: #{e.class} -- #{e.message}", :error)
      false
    end

    def inject!
      @injections.each(&:call)
    rescue => e
      Honeybadger.write_verbose_log("Exception caught while injecting dependency: #{e.class} -- #{e.message}", :error)
      false
    ensure
      @injected = true
    end

    def reset!
      @injected = false
    end

    def injected?
      @injected
    end

    attr_reader :requirements, :injections
  end
end
