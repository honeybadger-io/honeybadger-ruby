require "honeybadger/config"

describe Honeybadger::Config::Env do
  subject { described_class.new(env) }

  let(:env) { {} }

  before do
    env["HONEYBADGER_API_KEY"] = "asdf"
    env["HONEYBADGER_EXCEPTIONS_ENABLED"] = "false"
    env["HONEYBADGER_ENV"] = "production"
    env["HONEYBADGER_LOGGING_PATH"] = "log/"
    env["HONEYBADGER_EXCEPTIONS_IGNORE"] = "Foo, Bar, Baz"
  end

  it { should be_a Hash }

  specify { expect(subject[:api_key]).to eq "asdf" }
  specify { expect(subject[:env]).to eq "production" }
  specify { expect(subject[:"logging.path"]).to eq "log/" }
  specify { expect(subject[:"exceptions.ignore"]).to eq ["Foo", "Bar", "Baz"] }
  specify { expect(subject[:"exceptions.enabled"]).to eq false }

  context "with invalid options" do
    before do
      env["HONEYBADGER_BAD_OPTION"] = "log/"
    end

    specify { expect(subject).not_to have_key(:bad_option) }
  end

  context "with ignorable type" do
    before do
      env["HONEYBADGER_BREADCRUMBS_ACTIVE_SUPPORT_NOTIFICATIONS"] = "{}"
    end

    specify { expect(subject).not_to have_key(:"breadcrumbs.active_support_notifications") }
  end
end
