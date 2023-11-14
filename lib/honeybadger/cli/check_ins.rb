require 'forwardable'
require 'honeybadger/cli/main'
require 'honeybadger/cli/helpers'
require 'honeybadger/util/http'
require 'honeybadger/config_sync_service'
module Honeybadger
  module CLI
    class CheckIns < Thor

      extend Forwardable

      class_option :personal_auth_token, required: false, type: :string, desc: "personal auth token for API access"
      class_option :environment,     required: false, aliases: [:'-e', :'-env'], type: :string, desc: 'Environment this command is being executed in (i.e. "production", "staging")'
      class_option :skip_rails_load, required: false, type: :boolean, desc: 'Flag to skip rails initialization'
      
      desc "sync", "Sync check in configuration from config file"
      def sync
        config = build_config(options)
        if config.get(:personal_auth_token).to_s =~ BLANK
          say(config.inspect)
          say("No value provided for required options '--personal-auth-token'", :red)
          exit(1)
        end
        if (config.get(:checkins) || []).empty?
          say("No check_ins provided in config file", :red)
          exit(1)
        end
        config_sync_service = ConfigSyncService.new(config)
        result = config_sync_service.sync_checkins
        table = [["Id", "Name", "Slug", "Schedule Type", "Report Period", "Grace Period", "Cron Schedule", "Cron Timezone", "Status"]]
        table += result.map do |c|
          [c.id, c.name, c.slug, c.schedule_type, c.report_period, c.grace_period, c.cron_schedule, c.cron_timezone, c.deleted? ? "Deleted" : "Synced"]
        end
        print_table(table)
        say("Check in config synced", :green)
      end

      private

      include Helpers::Environment

      def build_config(options)
        load_env(options)

        config = Honeybadger.config
        config.set(:api_key, fetch_value(options, 'api_key')) if options.has_key?('api_key')
        config.set(:env, fetch_value(options, 'environment')) if options.has_key?('environment')
        config.set(:personal_auth_token, fetch_value(options, 'personal_auth_token')) if options.has_key?('personal_auth_token')
        config
      end


    end
  end
end