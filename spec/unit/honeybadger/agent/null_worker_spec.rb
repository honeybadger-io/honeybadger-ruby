describe Honeybadger::Agent::NullWorker do
  [:push, :shutdown, :shutdown!, :flush, :start].each do |method|
    it "responds to #{method}" do
      expect(subject).to respond_to(method)
      expect(subject.method(method).arity).to eq Honeybadger::Agent::Worker.instance_method(method).arity
    end
  end
end
