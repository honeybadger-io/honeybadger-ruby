require 'forwardable'
require 'honeybadger/agent'

# The Singleton module includes the public API for Honeybadger which can be
# accessed via the global agent (i.e. `Honeybadger.notify`) or via instances of
# the `Honeybadger::Agent` class.
module Honeybadger
  extend Forwardable
  extend self

  def_delegators :'Agent.instance', :init!, :config, :configure, :notify,
    :context, :get_context, :flush, :stop, :with_rack_env, :exception_filter,
    :exception_fingerprint, :backtrace_filter

  def load_plugins!
    Dir[File.expand_path('../plugins/*.rb', __FILE__)].each do |plugin|
      require plugin
    end
    Plugin.load!(self.config)
  end

  # Deprecated
  def start(config = {})
    true
  end
end
