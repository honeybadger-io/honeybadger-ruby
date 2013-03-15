Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  s.name              = 'honeybadger'
  s.version           = '1.6.1'
  s.date              = '2013-03-14'

  s.summary     = 'Error reports you can be happy about.'
  s.description = 'Make managing application errors a more pleasant experience.'

  s.authors  = ['Joshua Wood']
  s.email    = 'josh@honeybadger.io'
  s.homepage = 'http://www.honeybadger.io'

  s.require_paths = %w[lib]

  s.rdoc_options = ['--charset=UTF-8', '--markup tomdoc']
  s.extra_rdoc_files = %w[README.md MIT-LICENSE]

  s.add_dependency('json')

  s.add_development_dependency('cucumber',          '~> 1.2.1')
  s.add_development_dependency('rspec',             '~> 2.12.0')
  s.add_development_dependency('fakeweb',           '~> 1.3.0')
  s.add_development_dependency('sham_rack',         '~> 1.3.0')
  s.add_development_dependency('bourne',            '>= 1.0')
  s.add_development_dependency('shoulda',           '~> 2.11.3')
  s.add_development_dependency('capistrano')
  s.add_development_dependency('rake')
  s.add_development_dependency('sinatra')
  s.add_development_dependency('aruba')
  s.add_development_dependency('appraisal')

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    Appraisals
    CHANGELOG.md
    Gemfile
    Gemfile.lock
    Guardfile
    MIT-LICENSE
    README.md
    Rakefile
    features/metal.feature
    features/rack.feature
    features/rails.feature
    features/rake.feature
    features/sinatra.feature
    features/step_definitions/metal_steps.rb
    features/step_definitions/rack_steps.rb
    features/step_definitions/rails_steps.rb
    features/step_definitions/rake_steps.rb
    features/support/env.rb
    features/support/honeybadger_failure_shim.rb.template
    features/support/honeybadger_shim.rb.template
    features/support/rails.rb
    features/support/rake/Rakefile
    gemfiles/rack.gemfile
    gemfiles/rack.gemfile.lock
    gemfiles/rails2.3.gemfile
    gemfiles/rails2.3.gemfile.lock
    gemfiles/rails3.0.gemfile
    gemfiles/rails3.0.gemfile.lock
    gemfiles/rails3.1.gemfile
    gemfiles/rails3.1.gemfile.lock
    gemfiles/rails3.2.gemfile
    gemfiles/rails3.2.gemfile.lock
    gemfiles/rails4.gemfile
    gemfiles/rails4.gemfile.lock
    gemfiles/rake.gemfile
    gemfiles/rake.gemfile.lock
    gemfiles/sinatra.gemfile
    gemfiles/sinatra.gemfile.lock
    generators/honeybadger/honeybadger_generator.rb
    generators/honeybadger/lib/insert_commands.rb
    generators/honeybadger/lib/rake_commands.rb
    generators/honeybadger/templates/capistrano_hook.rb
    generators/honeybadger/templates/honeybadger_tasks.rake
    generators/honeybadger/templates/initializer.rb
    honeybadger.gemspec
    lib/honeybadger.rb
    lib/honeybadger/backtrace.rb
    lib/honeybadger/capistrano.rb
    lib/honeybadger/configuration.rb
    lib/honeybadger/notice.rb
    lib/honeybadger/rack.rb
    lib/honeybadger/rails.rb
    lib/honeybadger/rails/action_controller_catcher.rb
    lib/honeybadger/rails/controller_methods.rb
    lib/honeybadger/rails/middleware/exceptions_catcher.rb
    lib/honeybadger/rails3_tasks.rb
    lib/honeybadger/railtie.rb
    lib/honeybadger/rake_handler.rb
    lib/honeybadger/sender.rb
    lib/honeybadger/shared_tasks.rb
    lib/honeybadger/tasks.rb
    lib/honeybadger_tasks.rb
    lib/rails/generators/honeybadger/honeybadger_generator.rb
    rails/init.rb
    resources/README.md
    resources/ca-bundle.crt
    script/integration_test.rb
    test/test_helper.rb
    test/unit/backtrace_test.rb
    test/unit/capistrano_test.rb
    test/unit/configuration_test.rb
    test/unit/honeybadger_tasks_test.rb
    test/unit/logger_test.rb
    test/unit/notice_test.rb
    test/unit/notifier_test.rb
    test/unit/rack_test.rb
    test/unit/rails/action_controller_catcher_test.rb
    test/unit/rails_test.rb
    test/unit/sender_test.rb
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^test\/.*_test\.rb/ }
end
