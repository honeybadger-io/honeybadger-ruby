require 'spec_helper'
require 'capistrano'

if defined?(Capistrano::Configuration.instance)
  describe 'Honeybadger::Capistrano' do
    require 'capistrano/configuration'
    require 'honeybadger/capistrano'

    before { reset_config }

    before(:each) do
      @configuration = Capistrano::Configuration.new
      Honeybadger::Capistrano.load_into(@configuration)
      @configuration.dry_run = true
    end

    it "defines honeybadger:deploy task" do
      expect(@configuration.find_task('honeybadger:deploy')).not_to be_nil
    end

    it "logs when calling honeybadger:deploy task" do
      @configuration.set(:current_revision, '084505b1c0e0bcf1526e673bb6ac99fbcb18aecc')
      @configuration.set(:repository, 'repository')
      @configuration.set(:current_release, '/home/deploy/rails_app/honeybadger')
      io = StringIO.new
      logger = Capistrano::Logger.new(:output => io)
      logger.level = Capistrano::Logger::MAX_LEVEL

      @configuration.logger = logger
      @configuration.find_and_execute_task('honeybadger:deploy')

      expect(io.string).to include '** Notifying Honeybadger of Deploy'
      expect(io.string).to include '** Honeybadger Notification Complete'
    end
  end
end
