require 'honeybadger/version'

module Honeybadger
  # Autoloading allows middleware classes to be referenced in applications
  # which include the optional Rack dependency without explicitly requiring
  # these files.
  module Rack
    autoload :ErrorNotifier, 'honeybadger/rack/error_notifier'
    autoload :UserFeedback, 'honeybadger/rack/user_feedback'
    autoload :UserInformer, 'honeybadger/rack/user_informer'
  end
end
