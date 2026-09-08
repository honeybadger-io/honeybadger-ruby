require "honeybadger/breadcrumbs/active_support"

describe Honeybadger::Breadcrumbs::ActiveSupport do
  describe "sql.active_record" do
    let(:notification) { described_class.default_notifications["sql.active_record"] }
    let(:connection) { double("connection", adapter_name: "PostgreSQL") }

    it "obfuscates the sql" do
      data = notification[:transform].call({sql: "SELECT * FROM users WHERE id = 1", connection: connection})
      expect(data[:sql]).to eq "SELECT * FROM users WHERE id = ?"
    end

    context "when the sql is longer than sql.max_length" do
      before { Honeybadger.config[:"sql.max_length"] = 20 }
      after { Honeybadger.config[:"sql.max_length"] = Honeybadger::Config::DEFAULTS[:"sql.max_length"] }

      it "truncates the sql instead of obfuscating it" do
        data = notification[:transform].call({sql: "SELECT * FROM users WHERE name = 'secret'", connection: connection})
        expect(data[:sql]).to include("[truncated")
        expect(data[:sql]).not_to include("secret")
      end
    end

    describe "exclude_when" do
      it "excludes transaction statements" do
        expect(notification[:exclude_when].call({sql: "BEGIN"})).to be_truthy
        expect(notification[:exclude_when].call({sql: "COMMIT"})).to be_truthy
      end

      it "keeps other queries" do
        expect(notification[:exclude_when].call({sql: "SELECT 1"})).to be_falsey
      end

      it "does not scan long queries for transaction statements" do
        expect(notification[:exclude_when].call({sql: "#{"x" * 200}\nCOMMIT"})).to be_falsey
      end
    end
  end
end
