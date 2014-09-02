require 'honeybadger'

feature "Running the debug cli command" do
  before do
    set_env('HONEYBADGER_API_KEY', 'asdf')
  end

  scenario "in a standalone project" do
    it "displays all configuration options" do
      assert_cmd("honeybadger config")
      expect(all_output).to match /api_key/
      expect(all_output).to match /asdf/
      expect(all_output).to match /user_informer/
    end

    context "with the --no-default option" do
      it "skips default values" do
        assert_cmd("honeybadger config --no-default")
        expect(all_output).to match /api_key/
        expect(all_output).to match /asdf/
        expect(all_output).not_to match /user_informer/
      end
    end
  end
end
