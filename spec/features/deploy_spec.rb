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

  context "when Rails is not detected due to a missing environment.rb" do
    it "skips rails initialization without logging" do
      expect(run('honeybadger deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user --skip-rails-load')).to be_successfully_executed
      expect(all_output).to_not match(/Skipping Rails initialization/i)
    end
  end

  context "when Rails is detected via the presence of environment.rb" do
    before do
      config_path = File.join(Dir.pwd, 'tmp', 'features', 'config')
      Dir.mkdir(config_path) unless File.exists?(config_path)
      File.open(File.join(config_path, 'environment.rb'), 'w')
    end

    it "skips rails initialization when true" do
      expect(run('honeybadger deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user --skip-rails-load')).to be_successfully_executed
      expect(all_output).to match(/Skipping Rails initialization/i)
    end

    it "does not skip rails initialization when false or not set" do
      expect(run('honeybadger deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user --skip-rails-load=false')).to be_successfully_executed
      expect(all_output).to_not match(/Skipping Rails initialization/i)

      expect(run('honeybadger deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user')).to be_successfully_executed
      expect(all_output).to_not match(/Skipping Rails initialization/i)
    end
  end
end
