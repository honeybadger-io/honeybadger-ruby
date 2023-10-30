require 'honeybadger'

feature "Running the checkins cli command" do
  scenario "sync checkins" do
    it "syncs checkin configuration" do
      set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
      expect(run_command("honeybadger sync_checkins")).to be_successfully_executed
      pp all_output
    end
  end
end
 