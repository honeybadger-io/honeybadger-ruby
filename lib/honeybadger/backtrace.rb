module Honeybadger
  # Public: Front end to parsing the backtrace for each notice
  class Backtrace

    # Public: Handles backtrace parsing line by line
    class Line
      # regexp (optionnally allowing leading X: for windows support)
      INPUT_FORMAT = %r{^((?:[a-zA-Z]:)?[^:]+):(\d+)(?::in `([^']+)')?$}.freeze

      # Public: The file portion of the line (such as app/models/user.rb)
      attr_reader :file

      # Public: The line number portion of the line
      attr_reader :number

      # Public: The method of the line (such as index)
      attr_reader :method

      # Public: Parses a single line of a given backtrace
      #
      # unparsed_line - The raw line from +caller+ or some backtrace
      #
      # Returns the parsed backtrace line
      def self.parse(unparsed_line)
        _, file, number, method = unparsed_line.match(INPUT_FORMAT).to_a
        new(file, number, method)
      end

      def initialize(file, number, method)
        self.file   = file
        self.number = number
        self.method = method
      end

      # Public: Reconstructs the line in a readable fashion
      def to_s
        "#{file}:#{number}:in `#{method}'"
      end

      def ==(other)
        to_s == other.to_s
      end

      def inspect
        "<Line:#{to_s}>"
      end

      private

      attr_writer :file, :number, :method
    end

    # Public: holder for an Array of Backtrace::Line instances
    attr_reader :lines

    def self.parse(ruby_backtrace, opts = {})
      ruby_lines = split_multiline_backtrace(ruby_backtrace)

      filters = opts[:filters] || []
      filtered_lines = ruby_lines.to_a.map do |line|
        filters.inject(line) do |line, proc|
          proc.call(line)
        end
      end.compact

      lines = filtered_lines.collect do |unparsed_line|
        Line.parse(unparsed_line)
      end

      instance = new(lines)
    end

    def initialize(lines)
      self.lines = lines
    end

    # Public
    #
    # Returns array containing backtrace lines
    def to_ary
      lines.map { |l| { :number => l.number, :file => l.file, :method => l.method } }
    end
    alias :to_a :to_ary

    # Public: JSON support
    #
    # Returns JSON representation of backtrace
    def as_json(options = {})
      to_ary
    end

    # Public: Creates JSON
    #
    # Returns valid JSON representation of backtrace
    def to_json(*a)
      as_json.to_json(*a)
    end

    def inspect
      "<Backtrace: " + lines.collect { |line| line.inspect }.join(", ") + ">"
    end

    def ==(other)
      if other.respond_to?(:lines)
        lines == other.lines
      else
        false
      end
    end

    private

    attr_writer :lines

    def self.split_multiline_backtrace(backtrace)
      if backtrace.to_a.size == 1
        backtrace.to_a.first.split(/\n\s*/)
      else
        backtrace
      end
    end
  end
end
