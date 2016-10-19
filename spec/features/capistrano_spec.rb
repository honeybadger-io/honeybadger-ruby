feature "capistrano task" do
  before do
    FileUtils.cp(FIXTURES_PATH.join('Capfile'), current_dir)
  end

  it "outputs the honeybadger task" do
    expect(run('bundle exec cap -T')).to be_successfully_executed
    expect(all_output).to match(/honeybadger\:deploy/i)
  end
end
