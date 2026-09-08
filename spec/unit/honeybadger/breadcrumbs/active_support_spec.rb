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
  end
end
