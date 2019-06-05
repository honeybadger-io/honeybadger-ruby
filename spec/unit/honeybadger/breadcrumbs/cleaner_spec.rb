require 'honeybadger/breadcrumbs/cleaner'
require 'honeybadger/breadcrumbs/breadcrumb'

module Honeybadger::Breadcrumbs
  describe Cleaner do
    let(:logger) { double }
    let(:config) { double(logger: logger) }

    describe "#clean!" do
      context "metadata" do
        it "allows valid values" do
          [1, :neat, "me", true, false].each do |val|
            breadcrumb = instance_double(Breadcrumb, metadata: {k: val})
            described_class.new(config).clean!(breadcrumb)
            expect(breadcrumb.metadata).to eq({k: val})
          end
        end

        it "removes invalid values and logs to config logger" do
          [{}, [1, 2], Class.new()].each do |val|
            breadcrumb = instance_double(Breadcrumb, metadata: {k: val})
            expect(logger).to receive(:debug).with(/'k'/)
            described_class.new(config).clean!(breadcrumb)
            expect(breadcrumb.metadata).to eq({})
          end
        end
      end
    end
  end
end
