feature "Installing honeybadger via the cli" do
  shared_examples_for "capistrano deployment" do
    before do
      capify
      append_to_file('Capfile', %(\nrequire 'capistrano/honeybadger'))
    end

    it "outputs the honeybadger task" do
      expect(run('bundle exec cap -T')).to be_successfully_executed
      expect(all_output).to match(/honeybadger\:deploy/i)
    end
  end

  scenario "in a standalone project" do
    it_behaves_like "capistrano deployment"
  end

  scenario "in a Rails project", framework: :rails do
    it_behaves_like "capistrano deployment"
  end

end
