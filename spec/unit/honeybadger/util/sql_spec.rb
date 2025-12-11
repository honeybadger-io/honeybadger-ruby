require "honeybadger/util/sql"

RSpec.describe Honeybadger::Util::SQL do
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
  end
end
