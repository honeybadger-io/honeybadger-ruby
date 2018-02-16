require 'honeybadger/config'

describe Honeybadger::Config::Ruby do
  subject { described_class.new(config) }

  let(:config) { Honeybadger::Config.new(api_key: 'foo', :'user_informer.enabled' => true) }

  it { should respond_to(:api_key) }

  it "returns config values" do
    expect(subject.api_key).to eq('foo')
    expect(subject.user_informer.enabled).to eq(true)
  end

  it "returns config local values first" do
    subject.api_key = 'bar'
    subject.user_informer.enabled = false

    expect(subject.api_key).to eq('bar')
    expect(subject.user_informer.enabled).to eq(false)
  end

  it "converts config values to dotted Hash keys" do
    subject.api_key = 'bar'
    subject.user_informer.enabled = false

    expect(subject.to_hash).to eq({
      :api_key => 'bar',
      :'user_informer.enabled' => false
    })
  end

  it "doesn't respond to invalid methods" do
    expect { subject.foo = 'bar' }.to raise_error(NoMethodError)
    expect { subject.foo }.to raise_error(NoMethodError)
  end

  describe "#logger=" do
    it "assigns the logger to the Hash" do
      logger = double()
      subject.logger = logger
      expect(subject.to_hash).to eq({
        logger: logger
      })
    end
  end

  describe "#logger" do
    it "returns the assigned logger" do
      logger = double()
      subject.logger = logger
      expect(subject.logger).to eq(logger)
    end
  end

  describe "#backend=" do
    it "assigns the logger to the Hash" do
      backend = double()
      subject.backend = backend
      expect(subject.to_hash).to eq({
        backend: backend
      })
    end
  end

  describe "#backend" do
    it "returns the assigned backend" do
      backend = double()
      subject.backend = backend
      expect(subject.backend).to eq(backend)
    end
  end

  describe "#backtrace_filter" do
    it "assigns the backtrace_filter" do
      block = ->{}
      subject.backtrace_filter(&block)
      expect(subject.to_hash).to eq({
        backtrace_filter: block
      })
    end
  end

  describe "#before_notify" do
    it "adds a block as a before hook" do
      block = ->(_notice) {}

      subject.before_notify(&block)

      expect(subject.to_hash).to eq(before_notify: [block])
    end

    it "adds a callable as a before hook" do
      callable = ->(_notice) {}

      subject.before_notify(callable)

      expect(subject.to_hash).to eq(before_notify: [callable])
    end

    it "gives access to the before hooks when passed nothing" do
      expect(subject.before_notify).to eq([])

      callable = ->(_notice) {}
      subject.before_notify(callable)

      expect(subject.before_notify).to eq([callable])
    end
  end

  describe "#exception_filter" do
    it "assigns the exception_filter" do
      block = ->{}
      subject.exception_filter(&block)
      expect(subject.to_hash).to eq({
        exception_filter: block
      })
    end
  end

  describe "#exception_fingerprint" do
    it "assigns the exception_fingerprint" do
      block = ->{}
      subject.exception_fingerprint(&block)
      expect(subject.to_hash).to eq({
        exception_fingerprint: block
      })
    end
  end
end
