feature "capistrano task" do
  before do
    FileUtils.cp(FIXTURES_PATH.join('Capfile'), FEATURES_DIR)
  end

  it "outputs the honeybadger task" do
    cmd = run_command("bundle exec cap -T")
    expect(cmd).to be_successfully_executed
    expect(cmd.output).to match(/honeybadger:deploy/i)
  end
end
