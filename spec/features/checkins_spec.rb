require 'honeybadger'

feature "Running the checkins cli command" do
  scenario "sync checkins" do
    context "with config file" do

      let(:config_file_contents) { 
        {
          checkins: [
            {
              project_id: 'abcd',
              name: "worker checkin",
              schedule_type: "simple",
              report_period: "1 hour"
            }
          ] 
        }.to_yaml
      }
      let(:config_file) { TMP_DIR.join("honeybadger.yml") }
      before { 
        File.write(config_file, config_file_contents)
        set_environment_variable('HONEYBADGER_CONFIG_PATH', config_file)
        set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
      }

      after { File.unlink(config_file) }

      it "syncs checkin configuration" do
        expect(run_command("honeybadger sync_checkins")).to be_successfully_executed
      end
    end
  end
end
 