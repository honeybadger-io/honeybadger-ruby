require 'pathname'
require 'json'

module CommandLine
  # These override some deprecated Aruba helpers which are still useful to us.
  def all_output
    all_commands.map { |c| c.output }.join("\n")
  end
  def current_dir
    expand_path('.')
  end

  def capify
    unless run_simple('bundle exec cap install .', fail_on_error: false)
      run_simple('bundle exec capify .', fail_on_error: true)
    end
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
