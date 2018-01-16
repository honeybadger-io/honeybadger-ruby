feature "capistrano task" do
  before do
    FileUtils.cp(FIXTURES_PATH.join('Capfile'), current_dir)
  end

  after do
    puts '*' * 100
    puts 'PATH:'
    puts ENV['PATH']
    puts 'output:'
    puts all_output
    puts '*' * 100
  end

  it "outputs the honeybadger task" do
    expect(run('bundle exec cap -T')).to be_successfully_executed
    expect(all_output).to match(/honeybadger\:deploy/i)
  end
end
