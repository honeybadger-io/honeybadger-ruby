module Honeybadger::Integrations; end

require 'honeybadger/integrations/delayed_job'
require 'honeybadger/integrations/sidekiq'
require 'honeybadger/integrations/thor'
require 'honeybadger/integrations/net_http'
require 'honeybadger/integrations/passenger'
require 'honeybadger/integrations/unicorn'
require 'honeybadger/integrations/local_variables'
