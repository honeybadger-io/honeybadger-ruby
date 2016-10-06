require 'delegate'
require 'erb'
require 'fileutils'
require 'forwardable'
require 'json'
require 'logger'
require 'net/http'
require 'openssl'
require 'pathname'
require 'securerandom'
require 'set'
require 'singleton'
require 'socket'
require 'uri'
require 'yaml'
require 'zlib'

require 'honeybadger/version'

module Honeybadger
  autoload :Agent, 'honeybadger/agent'
  autoload :Backend, 'honeybadger/backend'
  autoload :Backtrace, 'honeybadger/backtrace'
  autoload :Config, 'honeybadger/config'
  autoload :Logging, 'honeybadger/logging'
  autoload :Notice, 'honeybadger/notice'
  autoload :Plugin, 'honeybadger/plugin'

  module Rack
    autoload :ErrorNotifier, 'honeybadger/rack/error_notifier'
    autoload :UserFeedback, 'honeybadger/rack/user_feedback'
    autoload :UserInformer, 'honeybadger/rack/user_informer'
    autoload :RequestHash, 'honeybadger/rack/request_hash'
    autoload :MetricsReporter, 'honeybadger/rack/metrics_reporter'
  end

  module Util
    autoload :Sanitizer, 'honeybadger/util/sanitizer'
    autoload :RequestPayload, 'honeybadger/util/request_payload'
    autoload :Stats, 'honeybadger/util/stats'
    autoload :HTTP, 'honeybadger/util/http'
  end
end
