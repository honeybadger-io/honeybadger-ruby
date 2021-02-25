require 'rails'
require 'action_controller/railtie'

# Duplicating here as some specs don't use the rails helper
SKIP_ACTIVE_RECORD = !!(defined?(JRUBY_VERSION) && Rails::VERSION::PRE == "alpha")

if SKIP_ACTIVE_RECORD
  module ActiveRecord
    class RecordNotFound < StandardError
    end
  end
else
  require 'active_record/railtie'
  require 'activerecord-jdbcsqlite3-adapter' if defined?(JRUBY_VERSION)
  require 'active_support'
  require 'active_support/core_ext/enumerable'
  ENV['DATABASE_URL'] = 'sqlite3::memory:'
end

require 'active_job/railtie'

ActiveSupport::Deprecation.silenced = true

class RailsApp < Rails::Application
  # Rails 6+
  if Rails::VERSION::MAJOR >= 6
    config.hosts << "www.example.com"
  end

  config.secret_key_base = 'test secret key base for test rails app'
  config.eager_load = true
  config.cache_classes = true
  config.serve_static_files = false
  config.consider_all_requests_local = false

  routes.append do
    get '/runtime_error', :to => 'rails#runtime_error'
    get '/record_not_found', :to => 'rails#record_not_found'
    root to: 'rails#index'
  end
end

# Required for install command.
class ApplicationController < ActionController::Base
end

class RailsController < ApplicationController
  def runtime_error
    raise 'exception raised from test Rails app in honeybadger gem test suite'
  end

  def record_not_found
    raise ActiveRecord::RecordNotFound
  end

  def index
    render plain: 'This is a test Rails app used by the honeybadger gem test suite.'
  end
end

Rails.env = 'production'
Rails.logger = Logger.new(File::NULL)

require_relative './breadcrumbs'
