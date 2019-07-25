module Honeybadger
  module Util
    class SQL
      EscapedQuotes = /(\\"|\\')/.freeze
      SQuotedData = /'(?:[^']|'')*'/.freeze
      DQuotedData = /"(?:[^"]|"")*"/.freeze
      NumericData = /\b\d+\b/.freeze
      Newline = /\n/.freeze
      Replacement = "?".freeze
      EmptyReplacement = "".freeze
      DoubleQuoters = /(postgres|sqlite|postgis)/.freeze

      def self.obfuscate(sql, adapter)
        sql.dup.tap do |s|
          s.gsub!(EscapedQuotes, EmptyReplacement)
          s.gsub!(SQuotedData, Replacement)
          s.gsub!(DQuotedData, Replacement) if adapter =~ DoubleQuoters
          s.gsub!(NumericData, Replacement)
          s.gsub!(Newline, EmptyReplacement)
          s.squeeze!(' ')
        end
      end
    end
  end
end
