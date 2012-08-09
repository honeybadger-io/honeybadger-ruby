<% if Rails::VERSION::MAJOR < 3 && Rails::VERSION::MINOR < 2 -%>
require 'honeybadger/rails'
<% end -%>
Honeybadger.configure do |config|
  config.api_key = <%= api_key_expression %>
end
