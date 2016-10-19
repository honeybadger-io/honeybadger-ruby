require 'rails'
require 'action_controller/railtie'

ActiveSupport::Deprecation.silenced = true

module ActiveRecord
  class RecordNotFound < StandardError
  end
end

class RailsApp < Rails::Application
  if Rails::VERSION::MAJOR == 3
    # For Rails 3.2
    config.secret_token = 'test secret token for test rails app'
    config.active_support.deprecation = :notify
  else
    # For Rails 4.0+
    config.secret_key_base = 'test secret key base for test rails app'
  end

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

class RailsController < ActionController::Base
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
Rails.logger = Logger.new('/dev/null')
