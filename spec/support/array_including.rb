module RSpec
  module Mocks
    module ArgumentMatchers
      class ArrayIncludingMatcher
        def initialize(expected)
          @expected = expected
        end

        def ==(actual)
          @expected.all? {|v| actual.include?(v) }
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
