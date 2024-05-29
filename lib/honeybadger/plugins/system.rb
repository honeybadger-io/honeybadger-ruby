require 'honeybadger/util/stats'
require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    module System
      Plugin.register :system do
        requirement { Util::Stats::HAS_MEM || Util::Stats::HAS_LOAD }

        collect do
          Honeybadger.event('report.system', Util::Stats.all)
        end
      end
    end
  end
end
