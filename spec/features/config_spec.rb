require 'honeybadger'

feature "Running the debug cli command" do
  before do
    set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
  end

  scenario "in a standalone project" do
    it "displays all configuration options" do
      expect(run("honeybadger config")).to be_successfully_executed
      expect(all_output).to match /api_key/
      expect(all_output).to match /asdf/
      expect(all_output).to match /user_informer/
    end

    context "with the --no-default option" do
      it "skips default values" do
        expect(run("honeybadger config --no-default")).to be_successfully_executed
        expect(all_output).to match /api_key/
        expect(all_output).to match /asdf/
        expect(all_output).not_to match /user_informer/
      end
    end
  end
end
