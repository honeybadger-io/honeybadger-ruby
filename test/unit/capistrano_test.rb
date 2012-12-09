require 'test_helper'

require 'capistrano/configuration'
require 'honeybadger/capistrano'

class CapistranoTest < Test::Unit::TestCase
  def setup
    super
    reset_config

    @configuration = Capistrano::Configuration.new
    Honeybadger::Capistrano.load_into(@configuration)
    @configuration.dry_run = true
  end

  should "define honeybadger:deploy task" do
    assert_not_nil @configuration.find_task('honeybadger:deploy')
  end

  should "log when calling honeybadger:deploy task" do
    @configuration.set(:current_revision, '084505b1c0e0bcf1526e673bb6ac99fbcb18aecc')
    @configuration.set(:repository, 'repository')
    @configuration.set(:current_release, '/home/deploy/rails_app/honeybadger')
    io = StringIO.new
    logger = Capistrano::Logger.new(:output => io)
    logger.level = Capistrano::Logger::MAX_LEVEL

    @configuration.logger = logger
    @configuration.find_and_execute_task('honeybadger:deploy')

    assert io.string.include?('** Notifying Honeybadger of Deploy')
    assert io.string.include?('** Honeybadger Notification Complete')
  end
end
