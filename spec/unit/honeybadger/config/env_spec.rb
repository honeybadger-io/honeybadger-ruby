require 'honeybadger/config'

describe Honeybadger::Config::Env do
  before do
    ENV['HONEYBADGER_API_KEY'] = 'asdf'
    ENV['HONEYBADGER_ENABLED'] = 'true'
    ENV['HONEYBADGER_ENV'] = 'production'
    ENV['HONEYBADGER_LOGGING_PATH'] = 'log/'
    ENV['HONEYBADGER_EXCEPTIONS_IGNORE'] = 'Foo, Bar, Baz'
  end

  it { should be_a Hash }

  specify { expect(subject[:api_key]).to eq 'asdf' }
  specify { expect(subject[:enabled]).to eq true }
  specify { expect(subject[:env]).to eq 'production' }
  specify { expect(subject[:'logging.path']).to eq 'log/' }
  specify { expect(subject[:'exceptions.ignore']).to eq ['Foo', 'Bar', 'Baz'] }
end
