require 'sham_rack'

describe Honeybadger::Rack::UserFeedback do
  let(:config) { Honeybadger::Config.new }
  let(:main_app) do
    lambda do |env|
      env['honeybadger.error_id'] = honeybadger_id if defined?(honeybadger_id)
      [200, {}, ["<!-- HONEYBADGER FEEDBACK -->"]]
    end
  end
  let(:informer_app) { Honeybadger::Rack::UserFeedback.new(main_app, config) }
  let(:response) { Net::HTTP.get_response(URI.parse("http://example.com/")) }

  before do
    ShamRack.mount(informer_app, "example.com")
  end

  context "feedback feature is disabled by ping" do
    it "does not modify the output" do
      expect(response.body).to eq '<!-- HONEYBADGER FEEDBACK -->'
    end
  end

  context "there is a honeybadger id" do
    let(:honeybadger_id) { 1 }

    it "modifies output" do
      rendered_length = informer_app.render_form(1).size
      expect(response.body).to match(/honeybadger_feedback_token/)
      expect(response["Content-Length"].to_i).to eq rendered_length
    end

    context "a project root is configured" do
      let(:tmp_dir) { TMP_DIR }
      let(:template_dir) { File.join(tmp_dir, 'lib', 'honeybadger', 'templates') }
      let(:template_file) { File.join(template_dir, 'feedback_form.erb') }

      before do
        FileUtils.mkdir_p(template_dir)
        FileUtils.rm_f(template_file)
        config[:root] = tmp_dir
      end

      context "custom template is implemented" do
        before do
          File.open(template_file, 'w') { |f| f.write 'custom feedback form' }
        end

        it "renders with custom template" do
          expect(response.body).to match(/custom feedback form/)
        end
      end
    end
  end

  context "there is no honeybadger id" do
    it "does not modify the output" do
      expect(response.body).to eq '<!-- HONEYBADGER FEEDBACK -->'
    end
  end
end
