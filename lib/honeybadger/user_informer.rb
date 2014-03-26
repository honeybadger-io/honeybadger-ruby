module Honeybadger
  class UserInformer < Rack::UserInformer
    def initialize(app)
      warn '[DEPRECATION] Honeybadger::UserInformer is deprecated in 2.0. Use Honeybadger::Rack::UserInformer.'
      super
    end
  end
end
