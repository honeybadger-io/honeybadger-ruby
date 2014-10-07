require 'json'

module Honeybadger
  # Internal: Front end to parsing the backtrace for each notice
  class Backtrace
    # Internal: Handles backtrace parsing line by line
    class Line
      # Backtrace line regexp (optionally allowing leading X: for windows support)
      INPUT_FORMAT = %r{^((?:[a-zA-Z]:)?[^:]+):(\d+)(?::in `([^']+)')?$}.freeze

      # The file portion of the line (such as app/models/user.rb)
      attr_reader :file

      # The line number portion of the line
      attr_reader :number

      # The method of the line (such as index)
      attr_reader :method

      # Filtered representations
      attr_reader :filtered_file, :filtered_number, :filtered_method

      # Parses a single line of a given backtrace
      #
      # unparsed_line - The raw line from +caller+ or some backtrace
      #
      # Returns the parsed backtrace line
      def self.parse(unparsed_line, opts = {})
        filters = opts[:filters] || []
        filtered_line = filters.reduce(unparsed_line) do |line, proc|
          # TODO: Break if nil
          if proc.arity == 2
            proc.call(line, opts[:config])
          else
            proc.call(line)
          end
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

      # Reconstructs the line in a readable fashion.
      def to_s
        "#{filtered_file}:#{filtered_number}:in `#{filtered_method}'"
      end

      def ==(other)
        to_s == other.to_s
      end

      def inspect
        "<Line:#{to_s}>"
      end

      # Determines if this line is part of the application trace or not.
      def application?
        (filtered_file =~ /^\[PROJECT_ROOT\]/i) && !(filtered_file =~ /^\[PROJECT_ROOT\]\/vendor/i)
      end

      # An excerpt from the source file, lazily loaded to preserve
      # performance.
      def source(radius = 2)
        @source ||= get_source(file, number, radius)
      end

      private

      attr_writer :file, :number, :method, :filtered_file, :filtered_number, :filtered_method

      # Open source file and read line(s).
      #
      # Returns an array of line(s) from source file.
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

    # Holder for an Array of Backtrace::Line instances.
    attr_reader :lines, :application_lines

    def self.parse(ruby_backtrace, opts = {})
      ruby_lines = split_multiline_backtrace(ruby_backtrace)

      lines = ruby_lines.collect do |unparsed_line|
        Line.parse(unparsed_line, opts)
      end.compact

      instance = new(lines)
    end

    def initialize(lines)
      self.lines = lines
      self.application_lines = lines.select(&:application?)
    end

    # Convert Backtrace to arry.
    #
    # Returns array containing backtrace lines.
    def to_ary
      lines.map { |l| { :number => l.filtered_number, :file => l.filtered_file, :method => l.filtered_method } }
    end
    alias :to_a :to_ary

    # JSON support.
    #
    # Returns JSON representation of backtrace.
    def as_json(options = {})
      to_ary
    end

    # Creates JSON.
    #
    # Returns valid JSON representation of backtrace.
    def to_json(*a)
      as_json.to_json(*a)
    end

    def to_s
      lines.map(&:to_s).join("\n")
    end

    def inspect
      "<Backtrace: " + lines.collect { |line| line.inspect }.join(", ") + ">"
    end

    def ==(other)
      if other.respond_to?(:to_json)
        to_json == other.to_json
      else
        false
      end
    end

    private

    attr_writer :lines, :application_lines

    def self.split_multiline_backtrace(backtrace)
      if backtrace.to_a.size == 1
        backtrace.to_a.first.split(/\n\s*/)
      else
        backtrace
      end
    end
  end
end
