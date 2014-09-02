feature "Installing honeybadger via the cli" do
  RSpec.shared_examples "capistrano deployment" do
    before do
      assert_cmd('bundle exec cap install .')
      append_to_file('Capfile', %(require 'capistrano/honeybadger'))
    end

    it "outputs the honeybadger task" do
      assert_cmd('bundle exec cap -T')
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
