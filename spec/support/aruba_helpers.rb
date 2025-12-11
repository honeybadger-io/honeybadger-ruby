require "json"

module ArubaHelpers
  # https://github.com/erikhuda/thor/blob/011dc48b5ea92767445b062f971664235973c8b4/spec/helper.rb#L49
  def capture(stream)
    begin
      stream = stream.to_s
      old_stream = eval("$#{stream}", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
      eval("$#{stream} = StringIO.new", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
      yield
      result = eval("$#{stream}", binding, __FILE__, __LINE__).string # rubocop:disable Security/Eval
    ensure
      # Restore the original stream
      case stream
      when "stdout"
        $stdout = old_stream
      when "stderr"
        $stderr = old_stream
      else
        eval("$#{stream} = old_stream", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
      end
    end

    result
  end

  # These override some deprecated Aruba helpers which are still useful to us.
  def all_output
    all_commands.map { |c| c.output }.join("\n")
  end

  def current_dir
    expand_path(".")
  end

  def assert_no_notification(output = all_output)
    expect(output).not_to match(/notifying debug backend of feature=notices/)
  end

  def assert_notification(expected = {})
    expect(all_output).to match(/notifying debug backend of feature=notices/)
    expect(all_output.scan("notifying debug backend of feature=notices").size).to eq 1
    notice = (all_output =~ /notifying debug backend of feature=notices\n\t(\{.+\})/) ? JSON.parse($1) : {}
    assert_hash_includes(expected, notice)
  end

  def assert_hash_includes(expected, actual)
    expected.each_pair do |k, v|
      if v.is_a?(Hash)
        expect(actual[k]).to be_a Hash
        assert_hash_includes(v, actual[k])
      else
        expect(actual[k]).to eq v
      end
    end
  end
end
