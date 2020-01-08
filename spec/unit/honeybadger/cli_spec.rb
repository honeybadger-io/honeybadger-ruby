require "honeybadger/cli"

module Honeybadger
  module CLI
    class Test
      def exit(status)
      end
    end
  end
end

describe Honeybadger::CLI::Main do
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  describe "commands" do
    describe "list" do
      it "displays available commands" do
        ARGV.replace %w(help)
        content = capture(:stdout) { described_class.start }
        expect(content).to match(/install API_KEY\s+# Install Honeybadger into a new project/m)
      end
    end

    describe "install" do
      let(:current_dir) { "" }
      let(:config_file) { Pathname(current_dir).join('honeybadger.yml') }

      it "creates config file" do
        ARGV.replace %w(install asdf)
        Dir.chdir("tmp") do
          FileUtils.safe_unlink("honeybadger.yml")
          expect {
            capture(:stdout) { described_class.start }
          }.to change { config_file.exist? }.from(false).to(true)
        end
      end
    end
  end
end
