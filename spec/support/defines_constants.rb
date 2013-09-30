module DefinesConstants
  def self.included(base)
    base.before(:each) do
      @defined_constants = []
    end

    base.after(:each) do
      @defined_constants.each do |constant|
        Object.__send__(:remove_const, constant)
      end
    end
  end

  def define_constant(name, value)
    Object.const_set(name, value)
    @defined_constants << name
  end
end
