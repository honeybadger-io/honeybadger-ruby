require 'honeybadger'

feature "Running the deploy cli command" do
  before { set_environment_variable('HONEYBADGER_BACKEND', 'debug') }

  it "notifies Honeybadger of the deploy" do
    expect(run('honeybadger deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user')).to be_successfully_executed
  end

  context "when the options are invalid" do
    it "notifies the user" do
      expect(run('honeybadger deploy --api-key= --environment=test-env --revision=test-rev --repository=test-repo --user=test-user')).not_to be_successfully_executed
      expect(all_output).to match(/required.+api-key/i)
    end
  end

  context "when there is a server error" do
    before { set_environment_variable('DEBUG_BACKEND_STATUS', '500') }

    it "notifies the user" do
      expect(run('honeybadger deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user')).not_to be_successfully_executed
      expect(all_output).to match(/request failed/i)
    end
  end
end
