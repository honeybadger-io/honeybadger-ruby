module Honeybadger
  class UserFeedback < Rack::UserFeedback
    def initialize(app)
      warn '[DEPRECATION] Honeybadger::UserFeedback is deprecated in 2.0. Use Honeybadger::Rack::UserFeedback.'
      super
    end
  end
end
