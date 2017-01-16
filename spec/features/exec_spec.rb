require 'honeybadger'

feature "Running the exec cli command", :focus do
  before { set_environment_variable('HONEYBADGER_BACKEND', 'debug') }

  it "quietly executes the requested command" do
    expect(run('honeybadger exec --api-key=test-api-key ls')).to be_successfully_executed
    expect(all_output).to be_empty
  end

  context "when the options are invalid" do
    it "notifies the user" do
      expect(run('honeybadger exec --api-key= ls')).not_to be_successfully_executed
      expect(all_output).to match(/required.+api-key/i)
    end
  end

  context "when the command fails due to a non-zero exit code" do
    it "notifies Honeybadger of the failure" do
      expect(run('honeybadger exec --api-key=test-api-key this-command-should-not-exist')).to be_successfully_executed
      expect(all_output).to match(/failed.+this-command-should-not-exist/im)
      expect(all_output).to match(/Successfully notified Honeybadger/i)
    end
  end

  context "when the command fails due to standard error output" do
    it "notifies Honeybadger of the failure" do
      expect(run('honeybadger exec --api-key=test-api-key echo "test stderr" 1>&2')).to be_successfully_executed
      expect(all_output).to match(/failure/i)
      expect(all_output).to match(/test stderr/i)
      expect(all_output).to match(/Successfully notified Honeybadger/i)
    end
  end
end
