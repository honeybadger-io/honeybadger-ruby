require 'forwardable'
require 'honeybadger/agent'

# The Singleton module includes the public API for Honeybadger which can be
# accessed via the global agent (i.e. `Honeybadger.notify`) or via instances of
# the `Honeybadger::Agent` class.
module Honeybadger
  extend Forwardable
  extend self

  def_delegators :'Honeybadger::Agent.instance', :init!, :config, :configure,
    :context, :get_context, :flush, :stop, :with_rack_env, :exception_filter,
    :exception_fingerprint, :backtrace_filter

  def notify(exception_or_opts, opts = {})
    Agent.instance.notify(exception_or_opts, opts)
  end

  def load_plugins!
    Dir[File.expand_path('../plugins/*.rb', __FILE__)].each do |plugin|
      require plugin
    end
    Plugin.load!(self.config)
  end

  # Deprecated
  def start(config = {})
    raise NoMethodError, <<-WARNING
`Honeybadger.start` is no longer necessary and has been removed.

  Use `Honeybadger.configure` to explicitly configure the agent from Ruby moving forward:

  Honeybadger.configure do |config|
    config.api_key = 'project api key'
    config.exceptions.ignore += [CustomError]
  end

  See https://git.io/v1Sd4 for documentation.
WARNING
  end
end
