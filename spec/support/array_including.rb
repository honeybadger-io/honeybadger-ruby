module RSpec
  module Mocks
    module ArgumentMatchers
      class ArrayIncludingMatcher
        def initialize(expected)
          @expected = expected
        end

        def ==(actual)
          @expected.all? do |value|
            if Regexp === value
              actual.any? {|v| value =~ v }
            else
              actual.include?(value)
            end
          end
        rescue NoMethodError
          false
        end

        def description
          "array_including(#{@expected.inspect})"
        end
      end

      def array_including(*args)
        ArrayIncludingMatcher.new(args.flatten)
      end
    end
  end
end
