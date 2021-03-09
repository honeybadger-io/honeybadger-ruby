require 'pathname'

# # Auto required by spec_helper.rb
# # https://relishapp.com/rspec/rspec-core/docs/example-groups/shared-examples
feature "in a plain ruby project", type: :feature do
  let(:config_file) { Pathname(FEATURES_DIR).join('honeybadger.yml') }

  it_behaves_like "cli installer", false
end

scenario "in a Rails project", framework: :rails do
  let(:config_file) { Pathname(File.join(FEATURES_DIR, "rails")).join('config', 'honeybadger.yml') }

  it_behaves_like "cli installer", true
end
