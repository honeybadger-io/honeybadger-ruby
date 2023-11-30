require 'honeybadger'

feature "Running the check_ins cli command" do
  scenario "sync check ins" do
    context "with config file" do
      let(:config_file_contents) { 
        {
          check_ins: [
            {
              project_id: 'abcd',
              name: "worker check in",
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
        set_environment_variable('HONEYBADGER_PERSONAL_AUTH_TOKEN', 'asdf')
        set_environment_variable('HONEYBADGER_BACKEND', 'test')
      }

      after { File.unlink(config_file) }

      it "syncs check in configuration" do
        expect(run_command("honeybadger check_ins sync --yes")).to be_successfully_executed
        expect(all_output).to match(/Check in config synced/)
        expect(all_output).to match(/1   worker check in/)
        expect(all_output).to match(/Synced/)
      end

      it "syncs check in configuration with manual confirmation" do
        run_command("honeybadger check_ins sync")
        type("y")
        stop_all_commands
        expect(last_command_started).to be_successfully_executed
        expect(all_output).to match(/Warning: Proceeding will replace all your current check-ins with the ones defined in the configuration file/)
        expect(all_output).to match(/Check in config synced/)
        expect(all_output).to match(/1   worker check in/)
        expect(all_output).to match(/Synced/)
      end

      it "does not sync check in configuration with manual confirmation denied" do
        run_command("honeybadger check_ins sync")
        type("n")
        stop_all_commands
        expect(last_command_started.exit_status).to be(1) 
        expect(all_output).to match(/Warning: Proceeding will replace all your current check-ins with the ones defined in the configuration file/)
      end
    end

    context "with config file without checkins" do
      let(:config_file_contents) { 
        {
        }.to_yaml
      }
      let(:config_file) { TMP_DIR.join("honeybadger.yml") }
      before { 
        File.write(config_file, config_file_contents)
        set_environment_variable('HONEYBADGER_CONFIG_PATH', config_file)
        set_environment_variable('HONEYBADGER_PERSONAL_AUTH_TOKEN', 'asdf')
        set_environment_variable('HONEYBADGER_BACKEND', 'test')
      }

      after { File.unlink(config_file) }

      it "does not sync check_in configuration if checkins are not configured in config file" do
        expect(run_command("honeybadger check_ins sync --yes")).to_not be_successfully_executed
        expect(all_output).to match(/No check_ins provided in config file/)
      end
    end
  end
end
 