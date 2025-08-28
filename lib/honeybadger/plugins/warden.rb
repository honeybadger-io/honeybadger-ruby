require "honeybadger/plugin"
require "honeybadger/ruby"

module Honeybadger
  Plugin.register do
    requirement { defined?(::Warden::Manager.after_set_user) }

    execution do
      ::Warden::Manager.after_set_user do |user, auth, opts|
        Honeybadger.context(user_scope: opts[:scope].to_s)
        Honeybadger.context(user_id: user.id.to_s) if user.respond_to?(:id)
        Honeybadger.context(user) if user.respond_to?(:to_honeybadger_context)
      end
    end
  end
end
