require "honeybadger/util/sql"

describe Honeybadger::Util::SQL do
  describe "#obfuscate" do
    it "works with non UTF-8 strings" do
      expect {
        described_class.obfuscate(
          "SELECT AES_DECRYPT('\x83ݔj\\\xE3Lb\u0001\\\xEC\u0010&\u000F[\\\xE6`q', 'key')",
          "sqlite3"
        )
      }.to_not raise_error
    end

    it "sanitizes SQL" do
      expect(described_class.obfuscate("SELECT * FROM users WHERE name = 'foo'", "mysql")).to eq "SELECT * FROM users WHERE name = '?'"
    end

    it "sanitizes SQL with double quotes" do
      expect(described_class.obfuscate('SELECT * FROM users WHERE name = "foo"', "mysql")).to eq 'SELECT * FROM users WHERE name = "?"'
    end

    it "sanitizes SQL with numbers" do
      expect(described_class.obfuscate("SELECT * FROM users WHERE id = 1", "mysql")).to eq "SELECT * FROM users WHERE id = ?"
    end

    it "sanitizes SQL with floats" do
      expect(described_class.obfuscate("SELECT * FROM users WHERE id = 1.0", "mysql")).to eq "SELECT * FROM users WHERE id = ?.?"
    end

    it "sanitizes SQL with multiple values" do
      expect(described_class.obfuscate("SELECT * FROM users WHERE id = 1 AND name = 'foo' LIMIT 1", "mysql")).to eq "SELECT * FROM users WHERE id = ? AND name = '?' LIMIT ?"
    end

    it "handles double-quoted strings" do
      expect(described_class.obfuscate(%(SELECT * FROM "users" WHERE name = 'foo'), "postgres")).to eq %(SELECT * FROM "users" WHERE name = '?')
    end

    describe "with max_length" do
      it "obfuscates normally when the SQL is within max_length" do
        expect(described_class.obfuscate("SELECT * FROM users WHERE name = 'foo'", "mysql", max_length: 1000)).to eq "SELECT * FROM users WHERE name = '?'"
      end

      it "replaces oversized SQL with a placeholder that keeps the statement head" do
        sql = %(INSERT INTO "solid_cache_entries" ("key", "value") VALUES ('\\xabc', '\\x#{"ff" * 100}'))
        expect(described_class.obfuscate(sql, "postgres", max_length: 100)).to eq "INSERT INTO \"solid_cache_entries\" (\"key\", \"value\") VALUES ( ... [truncated #{sql.bytesize} bytes]"
      end

      it "does not include single-quoted data from oversized SQL" do
        sql = "SELECT * FROM users WHERE name = 'secret#{"x" * 200}'"
        expect(described_class.obfuscate(sql, "postgres", max_length: 100)).not_to include("secret")
      end

      it "does not include double-quoted data from oversized SQL for adapters that quote data with double quotes" do
        sql = %(SELECT * FROM users WHERE name = "secret#{"x" * 200}")
        expect(described_class.obfuscate(sql, "mysql", max_length: 100)).not_to include("secret")
      end

      it "limits the head of oversized SQL to a short prefix" do
        sql = "SELECT * FROM users WHERE id IN (#{(1..1000).to_a.join(", ")})"
        expect(described_class.obfuscate(sql, "postgres", max_length: 100).bytesize).to be < 300
      end

      it "does not include dollar-quoted data from oversized SQL" do
        sql = "SELECT $$secret#{"x" * 200}$$"
        expect(described_class.obfuscate(sql, "postgres", max_length: 100)).not_to include("secret")
      end

      it "does not include comments from oversized SQL" do
        sql = "/* secret */ SELECT * FROM users WHERE id IN (#{(1..1000).to_a.join(", ")})"
        expect(described_class.obfuscate(sql, "postgres", max_length: 100)).not_to include("secret")
        sql = "-- secret\nSELECT * FROM users WHERE id IN (#{(1..1000).to_a.join(", ")})"
        expect(described_class.obfuscate(sql, "postgres", max_length: 100)).not_to include("secret")
      end

      it "keeps backtick-quoted identifiers in the head of oversized SQL" do
        sql = "INSERT INTO `solid_cache_entries` (`key`, `value`) VALUES ('a', '#{"x" * 200}')"
        expect(described_class.obfuscate(sql, "mysql", max_length: 100)).to start_with("INSERT INTO `solid_cache_entries` (`key`, `value`) VALUES ( ...")
      end

      it "does not include unquoted hexadecimal or binary literals from oversized SQL" do
        sql = "INSERT INTO t (a, b) VALUES (0xDEADBEEF, 0b1010) #{"x" * 200}"
        result = described_class.obfuscate(sql, "mysql", max_length: 100)
        expect(result).not_to include("DEADBEEF")
        expect(result).not_to include("1010")
      end
    end

    it "sanitizes unquoted hexadecimal and binary literals" do
      expect(described_class.obfuscate("INSERT INTO t (a, b) VALUES (0xDEADBEEF, 0b1010)", "mysql")).to eq "INSERT INTO t (a, b) VALUES (?, ?)"
    end
  end
end
