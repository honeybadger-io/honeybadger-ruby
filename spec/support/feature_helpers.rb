require 'json'

module FeatureHelpers
  # https://github.com/erikhuda/thor/blob/011dc48b5ea92767445b062f971664235973c8b4/spec/helper.rb#L49
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

  def current_dir
    File.expand_path('.')
  end

  def assert_no_notification(output)
    expect(output).not_to match(/notifying debug backend of feature=notices/)
  end

  def assert_notification(output, expected = {})
    expect(output).to match(/notifying debug backend of feature=notices/)
    expect(output.scan(/notifying debug backend of feature=notices/).size).to eq 1
    notice = output.match(/notifying debug backend of feature=notices\n\t(\{.+\})/) ? JSON.parse($1) : {}
    assert_hash_includes(expected, notice)
  end

  def assert_hash_includes(expected, actual)
    expected.each_pair do |k,v|
      if v.kind_of?(Hash)
        expect(actual[k]).to be_a Hash
        assert_hash_includes(v, actual[k])
      else
        expect(actual[k]).to eq v
      end
    end
  end


  # Used by run_command to return  a +cmd.exit_code+ and +cmd.output+
  TestCommand = Struct.new(:exit_code, :output, keyword_init: true)

  # https://github.com/erikhuda/thor/blob/011dc48b5ea92767445b062f971664235973c8b4/spec/script_exit_status_spec.rb#L1
  # Spawns a command and records the output and exitstatus. Generally should prefer Honeybadger::CLI.start(%w[])
  #   where possible.
  # @param {string} command - the command to run
  # @param {string} script_path [nil] - Path to the script to run.
  # @return {FeatureHelpers::TestCommand} - +.exit_code+ is 0-255 integer, +.output+ is the stdout / stderr.
  def run_command(command, script_path = nil)
    gem_dir = File.expand_path("#{File.dirname(__FILE__)}/..")
    lib_path = "#{gem_dir}/lib"
    ruby_lib = ENV['RUBYLIB'].nil? ? lib_path : "#{lib_path}:#{ENV['RUBYLIB']}"

    full_command = "#{script_path} #{command}"
    r,w = IO.pipe
    pid = spawn({'RUBYLIB' => ruby_lib},
               full_command,
               {:out => w, :err => [:child, :out]})
    w.close

    _, exit_status = Process.wait2(pid)
    output = r.read
    r.close

    FeatureHelpers::TestCommand.new(exit_code: exit_status.exitstatus, output: output)
  end
end

# Custom matchers similar to Aruba.
RSpec::Matchers.define :be_successfully_executed do
  match do |actual|
    actual.exit_code == 0
  end
end

RSpec::Matchers.define :not_be_successfully_executed do
  match do |actual|
    actual.exit_code != 1
  end
end
