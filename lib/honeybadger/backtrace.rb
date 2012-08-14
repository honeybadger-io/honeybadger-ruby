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

      # Public: Filtered representations
      attr_reader :filtered_file, :filtered_number, :filtered_method

      # Public: Parses a single line of a given backtrace
      #
      # unparsed_line - The raw line from +caller+ or some backtrace
      #
      # Returns the parsed backtrace line
      def self.parse(unparsed_line, opts = {})
        filters = opts[:filters] || []
        filtered_line = filters.inject(unparsed_line) do |line, proc|
          proc.call(line)
        end

        if filtered_line
          _, file, number, method = unparsed_line.match(INPUT_FORMAT).to_a
          _, *filtered_args = filtered_line.match(INPUT_FORMAT).to_a
          new(file, number, method, *filtered_args)
        else
          nil
        end
      end

      def initialize(file, number, method, filtered_file = file,
                     filtered_number = number, filtered_method = method)
        self.filtered_file   = filtered_file
        self.filtered_number = filtered_number
        self.filtered_method = filtered_method
        self.file            = file
        self.number          = number
        self.method          = method
      end

      # Public: Reconstructs the line in a readable fashion
      def to_s
        "#{filtered_file}:#{filtered_number}:in `#{filtered_method}'"
      end

      def ==(other)
        to_s == other.to_s
      end

      def inspect
        "<Line:#{to_s}>"
      end

      # Public: An excerpt from the source file, lazily loaded to preserve
      # performance
      def source(radius = 2)
        @source ||= get_source(file, number, radius)
      end

      private

      attr_writer :file, :number, :method, :filtered_file, :filtered_number, :filtered_method

      # Private: Open source file and read line(s)
      #
      # Returns an array of line(s) from source file
      def get_source(file, number, radius = 2)
        if file && File.exists?(file)
          before = after = radius
          start = (number.to_i - 1) - before
          start = 0 and before = 1 if start <= 0
          duration = before + 1 + after

          l = 0
          File.open(file) do |f|
            start.times { f.gets ; l += 1 }
            return Hash[duration.times.map { (line = f.gets) ? [(l += 1), line] : nil }.compact]
          end
        else
          {}
        end
      end
    end

    # Public: holder for an Array of Backtrace::Line instances
    attr_reader :lines

    def self.parse(ruby_backtrace, opts = {})
      ruby_lines = split_multiline_backtrace(ruby_backtrace)

      lines = ruby_lines.collect do |unparsed_line|
        Line.parse(unparsed_line, opts)
      end.compact

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
