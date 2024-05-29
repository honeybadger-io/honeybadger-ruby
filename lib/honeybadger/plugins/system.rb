require 'honeybadger/util/stats'
require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    module System
      Plugin.register :system do
        requirement { true }

        collect do
          Util::Stats.all.each do |resource, data|
            Honeybadger.event('report.system', data.merge(resource: resource))
          end
        end
      end
    end
  end
end
