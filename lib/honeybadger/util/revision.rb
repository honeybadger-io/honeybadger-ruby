module Honeybadger
  module Util
    class Revision
      class << self
        def detect(root = Dir.pwd)
          from_heroku ||
            from_capistrano(root) ||
            from_git
        end

        private

        # Requires (currently) alpha platform feature
        # `heroku labs:enable runtime-dyno-metadata`
        #
        # See https://devcenter.heroku.com/articles/dyno-metadata
        def from_heroku
          ENV['HEROKU_SLUG_COMMIT']
        end

        def from_capistrano(root)
          file = File.join(root, 'REVISION')
          return nil unless File.file?(file)
          File.read(file).strip rescue nil
        end

        def from_git
          return nil unless File.directory?('.git')
          `git rev-parse HEAD`.strip rescue nil
        end
      end
    end
  end
end
