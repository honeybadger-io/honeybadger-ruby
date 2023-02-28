# frozen_string_literal: true

require "hanami"

module HanamiApp
  class App < Hanami::App
  end

  class Routes < Hanami::Routes
    get "/runtime_error" do
      raise 'exception raised from test Hanami app in honeybadger gem test suite'
    end
  end
end

require "hanami/prepare"
