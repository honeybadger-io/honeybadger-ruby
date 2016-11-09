require 'honeybadger/agent'

# The Singleton module includes the public API for Honeybadger which can be
# accessed via the global agent (i.e. `Honeybadger.notify`) or via instances of
# the `Honeybadger::Agent` class.
module Honeybadger
  extend self

  def notify(exception_or_opts, opts = {})
    Agent.notify(exception_or_opts, opts)
  end

  def exception_filter(&block)
    Agent.exception_filter(&block)
  end

  def exception_fingerprint(&block)
    Agent.exception_fingerprint(&block)
  end

  def backtrace_filter(&block)
    Agent.backtrace_filter(&block)
  end

  def context(hash = nil)
    Agent.context(hash)
  end

  def get_context
    Agent.get_context
  end

  def flush(&block)
    Agent.flush(&block)
  end

  def stop
    Agent.stop
  end

  def config
    Agent.config
  end

  def configure(&block)
    Agent.configure(&block)
  end

  def with_rack_env(rack_env, &block)
    Agent.with_rack_env(rack_env, &block)
  end

  # Deprecated
  def start(config = {})
    true
  end
end
