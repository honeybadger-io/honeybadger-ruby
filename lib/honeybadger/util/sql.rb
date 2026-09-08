module Honeybadger
  module Util
    class SQL
      ESCAPE_QUOTES = /(\\"|\\')/
      SQUOTE_DATA = /'(?:[^']|'')*'/
      DQUOTE_DATA = /"(?:[^"]|"")*"/
      NUMBER_DATA = /\b\d+\b/
      DOUBLE_QUOTERS = /(postgres|sqlite|postgis)/i
      TRUNCATED_HEAD_LENGTH = 200

      # Obfuscates literal values in a SQL query. When +max_length+ is given
      # and the query is larger than that many bytes, the query is truncated
      # instead (see .truncate): scanning multi-megabyte queries (e.g. an
      # INSERT of a serialized cache value) is slow, and can exceed the
      # Regexp.timeout that Rails 8.1+ sets by default.
      def self.obfuscate(sql, adapter, max_length: nil)
        sql = sql.to_s
        return truncate(sql, adapter, max_length) if max_length && sql.bytesize > max_length

        force_utf_8(sql.dup).tap do |s|
          s.gsub!(/\s+/, " ")
          s.gsub!(ESCAPE_QUOTES, "".freeze)
          s.gsub!(SQUOTE_DATA, "'?'".freeze)
          s.gsub!(DQUOTE_DATA, '"?"'.freeze) unless adapter.to_s.match?(DOUBLE_QUOTERS)
          s.gsub!(NUMBER_DATA, "?".freeze)
          s.strip!
        end
      end

      # Keeps only the head of the statement (up to the first quoted value)
      # so that no literal data leaks, and notes the original size.
      def self.truncate(sql, adapter, max_length)
        head = force_utf_8(sql.byteslice(0, TRUNCATED_HEAD_LENGTH)).scrub("")
        head = head[0, head.index("'")] if head.include?("'")
        head = head[0, head.index('"')] if head.include?('"') && !adapter.to_s.match?(DOUBLE_QUOTERS)

        "#{obfuscate(head, adapter)} ... [truncated #{sql.bytesize} bytes]"
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
