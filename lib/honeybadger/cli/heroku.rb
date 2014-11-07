$:.unshift(File.expand_path('../../../../vendor/inifile/lib', __FILE__))

require 'honeybadger/cli/helpers'

module Honeybadger
  module CLI
    class Heroku < Thor
      include Helpers

      class_option :app, aliases: :'-a', type: :string, default: nil, desc: 'Specify optional Heroku APP'

      desc 'install API_KEY', 'Install Honeybadger on Heroku using API_KEY'
      def install(api_key)
        say("Installing Honeybadger #{VERSION} for Heroku")

        load_rails(verbose: true)

        ENV['HONEYBADGER_LOGGING_LEVEL']     = '2'
        ENV['HONEYBADGER_LOGGING_TTY_LEVEL'] = '0'
        ENV['HONEYBADGER_LOGGING_PATH']      = 'STDOUT'
        ENV['HONEYBADGER_REPORT_DATA']       = 'true'

        ENV['HONEYBADGER_API_KEY'] = api_key

        app = options[:app] || detect_heroku_app(false)
        say("Adding config HONEYBADGER_API_KEY=#{api_key} to Heroku.", :magenta)
        unless write_heroku_env({'HONEYBADGER_API_KEY' => api_key}, app)
          say('Unable to update heroku config. Do you need to specify an app name?', :red)
          exit(1)
        end

        config = Config.new(rails_framework_opts)
        Honeybadger.start(config) unless load_rails_env(verbose: true)
        say('Sending test notice', :yellow)
        unless Agent.instance && send_test(false)
          say("Honeybadger is installed, but failed to send a test notice. Try `HONEYBADGER_API_KEY=#{api_key} honeybadger test`.", :red)
          exit(1)
        end

        say("Installation complete. Happy 'badgering!", :green)
      end

      private

      # Public: Detects the Heroku app name from GIT.
      #
      # prompt_on_default - If a single remote is discoverd, should we prompt the
      #                     user before returning it?
      #
      # Returns the String app name if detected, otherwise nil.
      def detect_heroku_app(prompt_on_default = true)
        apps, git_config = {}, File.join(Dir.pwd, '.git', 'config')
        if File.exist?(git_config)
          require 'inifile'
          ini = IniFile.load(git_config)
          ini.each_section do |section|
            if match = section.match(/remote \"(?<remote>.+)\"/)
              url = ini[section]['url']
              if url_match = url.match(/heroku\.com:(?<app>.+)\.git$/)
                apps[match[:remote]] = url_match[:app]
              end
            end
          end

          if apps.size == 1
            if !prompt_on_default
              apps.values.first
            else
              say "We detected a Heroku app named #{apps.values.first}. Do you want to load the config? (y/yes or n/no)"
              if STDIN.gets.chomp =~ /(y|yes)/i
                apps.values.first
              end
            end
          elsif apps.size > 1
            say "We detected the following apps:"
            apps.each_with_index {|a,i| say "\s\s#{i+1}. #{a[1]}" }
            say "\s\s#{apps.size+1}. Use default"
            say "Please select an option (1-#{apps.size+1}):"
            apps.values[STDIN.gets.chomp.to_i-1]
          end
        end
      end

      def read_heroku_env(app = nil)
        cmd = ['heroku config']
        cmd << "--app #{app}" if app
        output = Bundler.with_clean_env { `#{cmd.join("\s")}` }
        return false unless $?.to_i == 0
        Hash[output.scan(/(HONEYBADGER_[^:]+):\s*(\S.*)\s*$/)]
      end

      def set_env_from_heroku(app = nil)
        return false unless env = read_heroku_env(app)
        env.each_pair do |k,v|
          ENV[k] ||= v
        end
      end

      def write_heroku_env(env, app = nil)
        cmd = ["heroku config:set"]
        Hash(env).each_pair {|k,v| cmd << "#{k}=#{v}" }
        cmd << "--app #{app}" if app
        Bundler.with_clean_env { `#{cmd.join("\s")}` }
        $?.to_i == 0
      end
    end
  end
end
