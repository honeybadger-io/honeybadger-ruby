feature "Rescuing exceptions in a rake task" do
  shared_examples_for "a rake application" do
    before do
      set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
      set_environment_variable('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
    end

    it "reports the exception to Honeybadger" do
      expect(run('rake honeybadger')).not_to be_successfully_executed
      assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Jim has left the building :('})
    end

    context "rake reporting is disabled" do
      before do
        set_environment_variable('HONEYBADGER_EXCEPTIONS_RESCUE_RAKE', 'false')
      end

      it "doesn't report the exception to Honeybadger" do
        expect(run('rake honeybadger')).not_to be_successfully_executed
        assert_no_notification
      end
    end

    context "shell is attached" do
      it "doesn't report the exception to Honeybadger" do
        expect(run('rake honeybadger_autodetect_from_terminal')).not_to be_successfully_executed
        assert_no_notification
      end

      context "rake reporting is enabled" do
        before do
          set_environment_variable('HONEYBADGER_EXCEPTIONS_RESCUE_RAKE', 'true')
        end

        it "reports the exception to Honeybadger" do
          expect(run('rake honeybadger_autodetect_from_terminal')).not_to be_successfully_executed
          assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Jim has left the building :('})
        end
      end
    end
  end

  scenario "in a standalone project", framework: :ruby do
    before do
      FileUtils.cp(FIXTURES_PATH.join('Rakefile'), current_dir)
    end

    it_behaves_like "a rake application"
  end

  scenario "in a Rails project", framework: :rails do
    before do
      FileUtils.cp(FIXTURES_PATH.join('Rakefile'), RAILS_ROOT.join('lib/tasks/honeybadger.rake'))
    end

    it_behaves_like "a rake application"
  end
end
