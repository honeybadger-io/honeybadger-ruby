feature "Rescuing exceptions in a rake task" do
  RSpec.shared_examples "a rake application" do
    before do
      set_env('HONEYBADGER_API_KEY', 'asdf')
      set_env('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
    end

    it "reports the exception to Honeybadger" do
      expect(cmd('rake honeybadger')).to exit_with(1)
      assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Jim has left the building :('})
    end

    context "rake reporting is disabled" do
      before do
        set_env('HONEYBADGER_EXCEPTIONS_RESCUE_RAKE', 'false')
      end

      it "reports the exception to Honeybadger" do
        expect(cmd('rake honeybadger')).to exit_with(1)
        assert_no_notification
      end
    end

    context "shell is attached" do
      it "reports the exception to Honeybadger" do
        expect(cmd('rake honeybadger_autodetect_from_terminal')).to exit_with(1)
        assert_no_notification
      end
    end
  end

  scenario "in a standalone project", framework: :rake do
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
