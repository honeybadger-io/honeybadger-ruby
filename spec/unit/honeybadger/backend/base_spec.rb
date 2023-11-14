require 'honeybadger/backend/base'
require 'honeybadger/config'

describe Honeybadger::Backend::Response do
  context "when successful" do
    subject { described_class.new(201) }
    its(:error) { should be_nil }
  end

  context "when unsuccessful" do
    subject { described_class.new(403, body) }

    context "body is missing" do
      let(:body) { nil }
      its(:error) { should be_nil }
    end

    context "body is empty" do
      let(:body) { "" }
      its(:error) { should be_nil }
    end

    context "body is valid JSON" do
      let(:body) { %({"error":"badgers"}) }
      its(:error) { should eq "badgers" }

      context "but invalid object" do
        let(:body) { %([{"error":"badgers"}]) }
        its(:error) { should be_nil }
      end
    end

    context "body is invalid JSON" do
      let(:body) { %({"error":"badgers") }
      its(:error) { should be_nil }
    end
  end
end

describe Honeybadger::Backend::Base do
  let(:config) { Honeybadger::Config.new }

  subject { described_class.new(config) }

  it { should respond_to :notify }

  describe "#notify" do
    it "raises NotImplementedError" do
      expect { subject.notify(:notices, double('Notice')) }.to raise_error NotImplementedError
    end
  end

  describe "#check_in" do
    it "raises NotImplementedError" do
      expect { subject.check_in(10) }.to raise_error NotImplementedError
    end
  end

  describe "#track_deployment" do
    it "defers the request to notify with the feature set as deploys" do
      opts = double(:opts)
      expect(subject).to receive(:notify).with(:deploys, opts)
      subject.track_deployment(opts)
    end
  end

  describe "check_in API methods" do
    describe "#get_checkin" do
      it "raises NotImplementedError" do
        expect { subject.get_check_in('abcd', 'efgh') }.to raise_error NotImplementedError
      end
    end

    describe "#get_checkins" do
      it "raises NotImplementedError" do
        expect { subject.get_check_ins('abcd') }.to raise_error NotImplementedError
      end
    end

    describe "#create_check_in" do
      it "raises NotImplementedError" do
        expect { subject.create_check_in('abcd', {}) }.to raise_error NotImplementedError
      end
    end

    describe "#update_check_in" do
      it "raises NotImplementedError" do
        expect { subject.update_check_in('abcd', 'efgh', {}) }.to raise_error NotImplementedError
      end
    end

    describe "#delete_check_in" do
      it "raises NotImplementedError" do
        expect { subject.delete_check_in('abcd', 'efgh') }.to raise_error NotImplementedError
      end
    end
  end
end
