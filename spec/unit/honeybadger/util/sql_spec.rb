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
  end
end

