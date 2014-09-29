require 'honeybadger/version'

module Honeybadger
  autoload :Agent, 'honeybadger/agent'
  autoload :Backend, 'honeybadger/backend'
  autoload :Backtrace, 'honeybadger/backtrace'
  autoload :Config, 'honeybadger/config'
  autoload :Logging, 'honeybadger/logging'
  autoload :Notice, 'honeybadger/notice'
  autoload :Trace, 'honeybadger/trace'
  autoload :Plugin, 'honeybadger/plugin'

  module Rack
    autoload :ErrorNotifier, 'honeybadger/rack/error_notifier'
    autoload :MetricsReporter, 'honeybadger/rack/metrics_reporter'
    autoload :UserFeedback, 'honeybadger/rack/user_feedback'
    autoload :UserInformer, 'honeybadger/rack/user_informer'
    autoload :RequestHash, 'honeybadger/rack/request_hash'
  end

  module Util
    autoload :Sanitizer, 'honeybadger/util/sanitizer'
    autoload :RequestSanitizer, 'honeybadger/util/request_sanitizer'
    autoload :Stats, 'honeybadger/util/stats'
    autoload :HTTP, 'honeybadger/util/http'
  end
end
