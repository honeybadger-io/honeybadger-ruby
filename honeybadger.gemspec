Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  s.name              = 'honeybadger'
  s.version           = '1.16.6'
  s.date              = '2014-11-26'

  s.summary     = 'Error reports you can be happy about.'
  s.description = 'Make managing application errors a more pleasant experience.'

  s.authors  = ['Joshua Wood']
  s.email    = 'josh@honeybadger.io'
  s.homepage = 'http://www.honeybadger.io'

  s.require_paths = %w[lib]

  s.rdoc_options = ['--charset=UTF-8', '--markup tomdoc']
  s.extra_rdoc_files = %w[README.md MIT-LICENSE]

  s.add_dependency('json')

  s.add_development_dependency('cucumber',   '~> 1.3.10')
  s.add_development_dependency('rspec',      '~> 2.14.0')
  s.add_development_dependency('sham_rack',  '~> 1.3.0')
  s.add_development_dependency('capistrano', '~> 2.0')
  s.add_development_dependency('guard',      '~> 1.8.3')
  s.add_development_dependency('guard-rspec')
  s.add_development_dependency('rake')
  s.add_development_dependency('sinatra')
  s.add_development_dependency('aruba')
  s.add_development_dependency('appraisal')
  s.add_development_dependency('fuubar')
  s.add_development_dependency('growl')

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
    features/rails3.x.feature
    features/rake.feature
    features/sinatra.feature
    features/standalone.feature
    features/step_definitions/metal_steps.rb
    features/step_definitions/rack_steps.rb
    features/step_definitions/rails_steps.rb
    features/step_definitions/rake_steps.rb
    features/step_definitions/standalone_steps.rb
    features/step_definitions/thor_steps.rb
    features/support/env.rb
    features/support/honeybadger_failure_shim.rb.template
    features/support/honeybadger_shim.rb.template
    features/support/rails.rb
    features/support/rake/Rakefile
    features/support/test.thor
    features/thor.feature
    gemfiles/binding_of_caller.gemfile
    gemfiles/delayed_job.gemfile
    gemfiles/rack.gemfile
    gemfiles/rails.gemfile
    gemfiles/rails2.3.gemfile
    gemfiles/rails3.0.gemfile
    gemfiles/rails3.1.gemfile
    gemfiles/rails3.2.gemfile
    gemfiles/rails4.1.gemfile
    gemfiles/rake.gemfile
    gemfiles/sinatra.gemfile
    gemfiles/standalone.gemfile
    gemfiles/thor.gemfile
    generators/honeybadger/honeybadger_generator.rb
    generators/honeybadger/lib/insert_commands.rb
    generators/honeybadger/lib/rake_commands.rb
    generators/honeybadger/templates/capistrano_hook.rb
    generators/honeybadger/templates/honeybadger_tasks.rake
    generators/honeybadger/templates/initializer.rb
    honeybadger.gemspec
    lib/honeybadger.rb
    lib/honeybadger/array.rb
    lib/honeybadger/backtrace.rb
    lib/honeybadger/capistrano.rb
    lib/honeybadger/capistrano/legacy.rb
    lib/honeybadger/capistrano/tasks.rake
    lib/honeybadger/configuration.rb
    lib/honeybadger/dependency.rb
    lib/honeybadger/integrations.rb
    lib/honeybadger/integrations/delayed_job.rb
    lib/honeybadger/integrations/delayed_job/plugin.rb
    lib/honeybadger/integrations/local_variables.rb
    lib/honeybadger/integrations/net_http.rb
    lib/honeybadger/integrations/passenger.rb
    lib/honeybadger/integrations/sidekiq.rb
    lib/honeybadger/integrations/thor.rb
    lib/honeybadger/integrations/unicorn.rb
    lib/honeybadger/monitor.rb
    lib/honeybadger/monitor/railtie.rb
    lib/honeybadger/monitor/sender.rb
    lib/honeybadger/monitor/trace.rb
    lib/honeybadger/monitor/worker.rb
    lib/honeybadger/notice.rb
    lib/honeybadger/payload.rb
    lib/honeybadger/rack.rb
    lib/honeybadger/rack/error_notifier.rb
    lib/honeybadger/rack/user_feedback.rb
    lib/honeybadger/rack/user_informer.rb
    lib/honeybadger/rails.rb
    lib/honeybadger/rails/action_controller_catcher.rb
    lib/honeybadger/rails/controller_methods.rb
    lib/honeybadger/rails/middleware/exceptions_catcher.rb
    lib/honeybadger/rails3_tasks.rb
    lib/honeybadger/railtie.rb
    lib/honeybadger/rake_handler.rb
    lib/honeybadger/sender.rb
    lib/honeybadger/shared_tasks.rb
    lib/honeybadger/stats.rb
    lib/honeybadger/tasks.rb
    lib/honeybadger/templates/feedback_form.erb
    lib/honeybadger/user_feedback.rb
    lib/honeybadger/user_informer.rb
    lib/honeybadger_tasks.rb
    lib/rails/generators/honeybadger/honeybadger_generator.rb
    rails/init.rb
    resources/README.md
    resources/ca-bundle.crt
    script/integration_test.rb
    spec/allocation_stats.rb
    spec/honeybadger/backtrace_spec.rb
    spec/honeybadger/capistrano_spec.rb
    spec/honeybadger/configuration_spec.rb
    spec/honeybadger/dependency_spec.rb
    spec/honeybadger/integrations/delayed_job_spec.rb
    spec/honeybadger/integrations/local_variables_spec.rb
    spec/honeybadger/integrations/net_http_spec.rb
    spec/honeybadger/integrations/passenger_spec.rb
    spec/honeybadger/integrations/sidekiq_spec.rb
    spec/honeybadger/integrations/thor_spec.rb
    spec/honeybadger/integrations/unicorn_spec.rb
    spec/honeybadger/logger_spec.rb
    spec/honeybadger/monitor/trace_spec.rb
    spec/honeybadger/monitor/worker_spec.rb
    spec/honeybadger/notice_spec.rb
    spec/honeybadger/notifier_spec.rb
    spec/honeybadger/payload_spec.rb
    spec/honeybadger/rack_spec.rb
    spec/honeybadger/rails/action_controller_spec.rb
    spec/honeybadger/rails_spec.rb
    spec/honeybadger/sender_spec.rb
    spec/honeybadger/stats_spec.rb
    spec/honeybadger/user_feedback_spec.rb
    spec/honeybadger/user_informer_spec.rb
    spec/honeybadger_tasks_spec.rb
    spec/spec_helper.rb
    spec/support/array_including.rb
    spec/support/backtraced_exception.rb
    spec/support/collected_sender.rb
    spec/support/defines_constants.rb
    spec/support/helpers.rb
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^test\/.*_test\.rb/ }
end
