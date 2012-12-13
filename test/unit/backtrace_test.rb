require 'test_helper'
require 'stringio'

class BacktraceTest < Test::Unit::TestCase
  should "parse a backtrace into lines" do
    array = [
      "app/models/user.rb:13:in `magic'",
      "app/controllers/users_controller.rb:8:in `index'"
    ]

    backtrace = Honeybadger::Backtrace.parse(array)

    line = backtrace.lines.first
    assert_equal '13', line.number
    assert_equal 'app/models/user.rb', line.file
    assert_equal 'magic', line.method

    line = backtrace.lines.last
    assert_equal '8', line.number
    assert_equal 'app/controllers/users_controller.rb', line.file
    assert_equal 'index', line.method
  end

  should "parse a windows backtrace into lines" do
    array = [
      "C:/Program Files/Server/app/models/user.rb:13:in `magic'",
      "C:/Program Files/Server/app/controllers/users_controller.rb:8:in `index'"
    ]

    backtrace = Honeybadger::Backtrace.parse(array)

    line = backtrace.lines.first
    assert_equal '13', line.number
    assert_equal 'C:/Program Files/Server/app/models/user.rb', line.file
    assert_equal 'magic', line.method

    line = backtrace.lines.last
    assert_equal '8', line.number
    assert_equal 'C:/Program Files/Server/app/controllers/users_controller.rb', line.file
    assert_equal 'index', line.method
  end

  should "be equal with equal lines" do
    one = build_backtrace_array
    two = one.dup

    assert_equal Honeybadger::Backtrace.parse(one), Honeybadger::Backtrace.parse(two)
  end

  should "parse massive one-line exceptions into multiple lines" do
    original_backtrace = Honeybadger::Backtrace.
      parse(["one:1:in `one'\n   two:2:in `two'\n      three:3:in `three`"])
    expected_backtrace = Honeybadger::Backtrace.
      parse(["one:1:in `one'", "two:2:in `two'", "three:3:in `three`"])

    assert_equal expected_backtrace, original_backtrace
  end

  context "when source file exists" do
    setup do
      source = <<-RUBY
        $:<<'lib'
        require 'honeybadger'

        begin
          raise StandardError
        rescue => e
          puts Honeybadger::Notice.new(exception: e).backtrace.to_json
        end
      RUBY

      array = [
        "app/models/user.rb:2:in `magic'",
        "app/concerns/authenticated_controller.rb:4:in `authorize'",
        "app/controllers/users_controller.rb:8:in `index'"
      ]

      ['app/models/user.rb', 'app/concerns/authenticated_controller.rb', 'app/controllers/users_controller.rb'].each do |file|
        File.expects(:exists?).with(file).returns true
        File.expects(:open).with(file).yields StringIO.new(source)
      end

      @backtrace = Honeybadger::Backtrace.parse(array)
    end

    should "include a snippet from the source file for each line of the backtrace" do
      assert_equal 4, @backtrace.lines.first.source.keys.size
      assert_match /\$:<</, @backtrace.lines.first.source[1]
      assert_match /require/, @backtrace.lines.first.source[2]
      assert_match /\n/, @backtrace.lines.first.source[3]
      assert_match /begin/, @backtrace.lines.first.source[4]

      assert_equal 5, @backtrace.lines.second.source.keys.size
      assert_match /require/, @backtrace.lines.second.source[2]
      assert_match /\n/, @backtrace.lines.second.source[3]
      assert_match /begin/, @backtrace.lines.second.source[4]
      assert_match /StandardError/, @backtrace.lines.second.source[5]
      assert_match /rescue/, @backtrace.lines.second.source[6]

      assert_equal 3, @backtrace.lines.third.source.keys.size
      assert_match /rescue/, @backtrace.lines.third.source[6]
      assert_match /Honeybadger/, @backtrace.lines.third.source[7]
      assert_match /end/, @backtrace.lines.third.source[8]
    end
  end

  should "fail gracefully when looking up snippet and file doesn't exist" do
    array = [
      "app/models/user.rb:13:in `magic'",
      "app/controllers/users_controller.rb:8:in `index'"
    ]

    backtrace = Honeybadger::Backtrace.parse(array)

    assert_equal backtrace.lines.first.source, {}
    assert_equal backtrace.lines.second.source, {}
  end

  should "have an empty application trace by default" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)
    assert_equal backtrace.application_lines, []
  end

  context "with a project root" do
    setup do
      @project_root = '/some/path'
      Honeybadger.configure {|config| config.project_root = @project_root }

      @backtrace_with_root = Honeybadger::Backtrace.parse(
        ["#{@project_root}/app/models/user.rb:7:in `latest'",
         "#{@project_root}/app/controllers/users_controller.rb:13:in `index'",
         "#{@project_root}/vendor/plugins/foo/bar.rb:42:in `baz'",
         "/lib/something.rb:41:in `open'"],
         :filters => default_filters)
      @backtrace_without_root = Honeybadger::Backtrace.parse(
        ["[PROJECT_ROOT]/app/models/user.rb:7:in `latest'",
         "[PROJECT_ROOT]/app/controllers/users_controller.rb:13:in `index'",
         "[PROJECT_ROOT]/vendor/plugins/foo/bar.rb:42:in `baz'",
         "/lib/something.rb:41:in `open'"])
    end

    should "filter out the project root" do
      assert_equal @backtrace_without_root, @backtrace_with_root
    end

    should "have an application trace" do
      assert_equal @backtrace_without_root.application_lines, @backtrace_without_root.lines[0..1]
    end

    should "filter ./vendor from application trace" do
      assert_does_not_contain @backtrace_without_root.application_lines, @backtrace_without_root.lines[2]
    end
  end

  context "with a project root equals to a part of file name" do
    setup do
      # Heroku-like
      @project_root = '/app'
      Honeybadger.configure {|config| config.project_root = @project_root }
    end

    should "filter out the project root" do
      backtrace_with_root = Honeybadger::Backtrace.parse(
        ["#{@project_root}/app/models/user.rb:7:in `latest'",
         "#{@project_root}/app/controllers/users_controller.rb:13:in `index'",
         "/lib/something.rb:41:in `open'"],
         :filters => default_filters)
         backtrace_without_root = Honeybadger::Backtrace.parse(
           ["[PROJECT_ROOT]/app/models/user.rb:7:in `latest'",
            "[PROJECT_ROOT]/app/controllers/users_controller.rb:13:in `index'",
            "/lib/something.rb:41:in `open'"])

            assert_equal backtrace_without_root, backtrace_with_root
    end
  end

  context "with a blank project root" do
    setup do
      Honeybadger.configure {|config| config.project_root = '' }
    end

    should "not filter line numbers with respect to any project root" do
      backtrace = ["/app/models/user.rb:7:in `latest'",
                   "/app/controllers/users_controller.rb:13:in `index'",
                   "/lib/something.rb:41:in `open'"]

      backtrace_with_root =
        Honeybadger::Backtrace.parse(backtrace, :filters => default_filters)

      backtrace_without_root =
        Honeybadger::Backtrace.parse(backtrace)

      assert_equal backtrace_without_root, backtrace_with_root
    end
  end

  should "remove notifier trace" do
    inside_notifier  = ['lib/honeybadger.rb:13:in `voodoo`']
    outside_notifier = ['users_controller:8:in `index`']

    without_inside = Honeybadger::Backtrace.parse(outside_notifier)
    with_inside    = Honeybadger::Backtrace.parse(inside_notifier + outside_notifier,
                                                  :filters => default_filters)

    assert_equal without_inside, with_inside
  end

  should "run filters on the backtrace" do
    filters = [lambda { |line| line.sub('foo', 'bar') }]
    input = Honeybadger::Backtrace.parse(["foo:13:in `one'", "baz:14:in `two'"],
                                         :filters => filters)
    expected = Honeybadger::Backtrace.parse(["bar:13:in `one'", "baz:14:in `two'"])
    assert_equal expected, input
  end

  should "alias #to_ary as #to_a" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)

    assert_equal backtrace.to_a, backtrace.to_ary
  end

  should "generate json from to_array template" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)
    array = [{'foo' => 'bar'}]
    backtrace.expects(:to_ary).once.returns(array)
    json = backtrace.to_json

    payload = nil
    assert_nothing_raised do
      payload = JSON.parse(json)
    end

    assert_equal payload, array
  end

  def build_backtrace_array
    ["app/models/user.rb:13:in `magic'",
     "app/controllers/users_controller.rb:8:in `index'"]
  end

  def default_filters
    Honeybadger::Configuration::DEFAULT_BACKTRACE_FILTERS
  end
end
