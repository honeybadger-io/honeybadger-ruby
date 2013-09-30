require 'spec_helper'
require 'stringio'

describe Honeybadger::Backtrace do
  it "parses a backtrace into lines" do
    array = [
      "app/models/user.rb:13:in `magic'",
      "app/controllers/users_controller.rb:8:in `index'"
    ]

    backtrace = Honeybadger::Backtrace.parse(array)

    line = backtrace.lines.first
    expect(line.number).to eq '13'
    expect(line.file).to eq 'app/models/user.rb'
    expect(line.method).to eq 'magic'

    line = backtrace.lines.last
    expect(line.number).to eq '8'
    expect(line.file).to eq 'app/controllers/users_controller.rb'
    expect(line.method).to eq 'index'
  end

  it "parses a windows backtrace into lines" do
    array = [
      "C:/Program Files/Server/app/models/user.rb:13:in `magic'",
      "C:/Program Files/Server/app/controllers/users_controller.rb:8:in `index'"
    ]

    backtrace = Honeybadger::Backtrace.parse(array)

    line = backtrace.lines.first
    expect(line.number).to eq '13'
    expect(line.file).to eq 'C:/Program Files/Server/app/models/user.rb'
    expect(line.method).to eq 'magic'

    line = backtrace.lines.last
    expect(line.number).to eq '8'
    expect(line.file).to eq 'C:/Program Files/Server/app/controllers/users_controller.rb'
    expect(line.method).to eq 'index'
  end

  it "is equal with equal lines" do
    one = build_backtrace_array
    two = one.dup

    expect(Honeybadger::Backtrace.parse(one)).to eq Honeybadger::Backtrace.parse(two)
  end

  it "parses massive one-line exceptions into multiple lines" do
    original_backtrace = Honeybadger::Backtrace.
      parse(["one:1:in `one'\n   two:2:in `two'\n      three:3:in `three`"])
    expected_backtrace = Honeybadger::Backtrace.
      parse(["one:1:in `one'", "two:2:in `two'", "three:3:in `three`"])

    expect(expected_backtrace).to eq original_backtrace
  end

  context "when source file exists" do
    before(:each) do
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
        File.should_receive(:exists?).with(file).and_return true
        File.should_receive(:open).with(file).and_yield StringIO.new(source)
      end

      @backtrace = Honeybadger::Backtrace.parse(array)
    end

    it "includes a snippet from the source file for each line of the backtrace" do
      expect(@backtrace.lines[0].source.keys.size).to eq(4)
      expect(@backtrace.lines[0].source[1]).to match(/\$:<</)
      expect(@backtrace.lines[0].source[2]).to match(/require/)
      expect(@backtrace.lines[0].source[3]).to match(/\n/)
      expect(@backtrace.lines[0].source[4]).to match(/begin/)

      expect(@backtrace.lines[1].source.keys.size).to eq(5)
      expect(@backtrace.lines[1].source[2]).to match(/require/)
      expect(@backtrace.lines[1].source[3]).to match(/\n/)
      expect(@backtrace.lines[1].source[4]).to match(/begin/)
      expect(@backtrace.lines[1].source[5]).to match(/StandardError/)
      expect(@backtrace.lines[1].source[6]).to match(/rescue/)

      expect(@backtrace.lines[2].source.keys.size).to eq(3)
      expect(@backtrace.lines[2].source[6]).to match(/rescue/)
      expect(@backtrace.lines[2].source[7]).to match(/Honeybadger/)
      expect(@backtrace.lines[2].source[8]).to match(/end/)
    end
  end

  it "fails gracefully when looking up snippet and file doesn't exist" do
    array = [
      "app/models/user.rb:13:in `magic'",
      "app/controllers/users_controller.rb:8:in `index'"
    ]

    backtrace = Honeybadger::Backtrace.parse(array)

    expect(backtrace.lines[0].source).to be_empty
    expect(backtrace.lines[1].source).to be_empty
  end

  it "has an empty application trace by default" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)
    expect(backtrace.application_lines).to be_empty
  end

  context "with a project root" do
    before(:each) do
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

    it "filters out the project root" do
      expect(@backtrace_without_root).to eq @backtrace_with_root
    end

    it "has an application trace" do
      expect(@backtrace_without_root.application_lines).to eq @backtrace_without_root.lines[0..1]
    end

    it "filters ./vendor from application trace" do
      expect(@backtrace_without_root.application_lines).not_to include(@backtrace_without_root.lines[2])
    end
  end

  context "with a project root equals to a part of file name" do
    before(:each) do
      # Heroku-like
      @project_root = '/app'
      Honeybadger.configure {|config| config.project_root = @project_root }
    end

    it "filters out the project root" do
      backtrace_with_root = Honeybadger::Backtrace.parse(
        ["#{@project_root}/app/models/user.rb:7:in `latest'",
         "#{@project_root}/app/controllers/users_controller.rb:13:in `index'",
         "/lib/something.rb:41:in `open'"],
         :filters => default_filters)
         backtrace_without_root = Honeybadger::Backtrace.parse(
           ["[PROJECT_ROOT]/app/models/user.rb:7:in `latest'",
            "[PROJECT_ROOT]/app/controllers/users_controller.rb:13:in `index'",
            "/lib/something.rb:41:in `open'"])

         expect(backtrace_without_root).to eq backtrace_with_root
    end
  end

  context "with a blank project root" do
    before(:each) do
      Honeybadger.configure {|config| config.project_root = '' }
    end

    it "does not filter line numbers with respect to any project root" do
      backtrace = ["/app/models/user.rb:7:in `latest'",
                   "/app/controllers/users_controller.rb:13:in `index'",
                   "/lib/something.rb:41:in `open'"]

      backtrace_with_root =
        Honeybadger::Backtrace.parse(backtrace, :filters => default_filters)

      backtrace_without_root =
        Honeybadger::Backtrace.parse(backtrace)

      expect(backtrace_without_root).to eq backtrace_with_root
    end
  end

  it "removes notifier trace" do
    inside_notifier  = ['lib/honeybadger.rb:13:in `voodoo`']
    outside_notifier = ['users_controller:8:in `index`']

    without_inside = Honeybadger::Backtrace.parse(outside_notifier)
    with_inside    = Honeybadger::Backtrace.parse(inside_notifier + outside_notifier,
                                                  :filters => default_filters)

    expect(without_inside).to eq with_inside
  end

  it "runs filters on the backtrace" do
    filters = [lambda { |line| line.sub('foo', 'bar') }]
    input = Honeybadger::Backtrace.parse(["foo:13:in `one'", "baz:14:in `two'"],
                                         :filters => filters)
    expected = Honeybadger::Backtrace.parse(["bar:13:in `one'", "baz:14:in `two'"])
    expect(expected).to eq input
  end

  it "aliases #to_ary as #to_a" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)

    expect(backtrace.to_a).to eq backtrace.to_ary
  end

  it "generates json from to_array template" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)
    array = [{'foo' => 'bar'}]
    backtrace.should_receive(:to_ary).once.and_return(array)
    json = backtrace.to_json

    payload = nil
    expect { payload = JSON.parse(json) }.not_to raise_error

    expect(payload).to eq array
  end

  def build_backtrace_array
    ["app/models/user.rb:13:in `magic'",
     "app/controllers/users_controller.rb:8:in `index'"]
  end

  def default_filters
    Honeybadger::Configuration::DEFAULT_BACKTRACE_FILTERS
  end
end
