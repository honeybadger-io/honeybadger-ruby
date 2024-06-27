module Honeybadger
  module Util
    class SQL
      ESCAPE_QUOTES = /(\\"|\\')/
      SQUOTE_DATA = /'(?:[^']|'')*'/
      DQUOTE_DATA = /"(?:[^"]|"")*"/
      NUMBER_DATA = /\b\d+\b/
      DOUBLE_QUOTERS = /(postgres|sqlite|postgis)/i

      def self.obfuscate(sql, adapter)
        force_utf_8(sql.to_s.dup).tap do |s|
          s.gsub!(/\s+/, " ")
          s.gsub!(ESCAPE_QUOTES, "".freeze)
          s.gsub!(SQUOTE_DATA, "'?'".freeze)
          s.gsub!(DQUOTE_DATA, '"?"'.freeze) unless adapter.to_s.match?(DOUBLE_QUOTERS)
          s.gsub!(NUMBER_DATA, "?".freeze)
          s.strip!
        end
      end

      def self.force_utf_8(string)
        string.encode(
          Encoding.find("UTF-8"),
          invalid: :replace,
          undef: :replace,
          replace: ""
        )
      end
    end
  end
end
