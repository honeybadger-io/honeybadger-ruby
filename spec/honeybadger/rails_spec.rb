require 'spec_helper'
require 'honeybadger/rails'

describe Honeybadger::Rails do
  include DefinesConstants

  it "triggers use of Rails' logger if logger isn't set and Rails' logger exists" do
    rails = Module.new do
      def self.logger
        "RAILS LOGGER"
      end
    end
    define_constant("Rails", rails)
    Honeybadger::Rails.initialize
    expect(Honeybadger.logger).to eq "RAILS LOGGER"
  end

  it "triggers use of Rails' default logger if logger isn't set and Rails.logger doesn't exist" do
    define_constant("RAILS_DEFAULT_LOGGER", "RAILS DEFAULT LOGGER")

    Honeybadger::Rails.initialize
    expect(Honeybadger.logger).to eq "RAILS DEFAULT LOGGER"
  end

  it "allows overriding of the logger if already assigned" do
    define_constant("RAILS_DEFAULT_LOGGER", "RAILS DEFAULT LOGGER")
    Honeybadger::Rails.initialize

    Honeybadger.configure(true) do |config|
      config.logger = "OVERRIDDEN LOGGER"
    end

    expect(Honeybadger.logger).to eq "OVERRIDDEN LOGGER"
  end
end
