
Dir[File.join(File.dirname(__FILE__), '..', 'vendor', 'gems', 'honeybadger-*')].each do |vendored_notifier|
  $: << File.join(vendored_notifier, 'lib')
end

require 'honeybadger/capistrano'
