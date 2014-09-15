require 'forwardable'
require 'pathname'
require 'aruba'
require 'aruba/api'
require 'fileutils'
require 'json'

CMD_ROOT = Pathname.new(File.expand_path('../../../tmp/features', __FILE__))
RAILS_ROOT = CMD_ROOT.join('current')

module ArubaApiWrapper
  include Aruba::Api
  extend self

  attr_writer :dirs, :aruba_timeout_seconds, :aruba_io_wait_seconds, :processes
end

module CommandLine
  extend Forwardable

  def_delegators :ArubaApiWrapper, :run_simple, :unescape, :cd, :all_output,
    :set_env, :restore_env, :write_file, :clean_current_dir,
    :terminate_processes!, :processes=, :dirs=, :aruba_timeout_seconds=,
    :aruba_io_wait_seconds=, :last_exit_status, :append_to_file, :current_dir

  Result = Struct.new(:cmd, :code) do
    def success?
      (200..299).cover?(code.to_i)
    end
  end

  def cmd(cmd, fail_on_error = false)
    run_simple(unescape(cmd), fail_on_error)
    Result.new(cmd, last_exit_status)
  end

  def assert_cmd(cmd)
    cmd(cmd, true)
  end

  def assert_no_notification
    expect(all_output).not_to match(/notifying debug backend of feature=notices/)
  end

  def assert_notification(expected = {})
    expect(all_output).to match(/notifying debug backend of feature=notices/)
    expect(all_output.scan(/notifying debug backend of feature=notices/).size).to eq 1
    notice = all_output.match(/notifying debug backend of feature=notices\n\t(\{.+\})/) ? JSON.parse($1) : {}
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
end

RSpec::Matchers.define :run_successfully do |expected|
  match do |actual|
    actual.code == 0
  end

  failure_message do |actual|
    "expected that `#{actual.cmd}` to exit with 0. (exited with #{actual.code})"
  end
end

RSpec::Matchers.define :exit_with do |expected|
  match do |actual|
    actual.code == expected
  end

  failure_message do |actual|
    "expected that `#{actual.cmd}` to exit with #{expected}. (exited with #{actual.code})"
  end
end
