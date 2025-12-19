require "honeybadger/context_manager"

TestContext = Honeybadger::ContextManager.new(:__hb_test_context)

RSpec.describe TestContext do
  subject(:context_manager) { described_class }

  before do
    context_manager.clear
  end

  describe "#set_context" do
    it "retrieves the context" do
      context_manager.set_context(shop_id: :expected_shop_id)
      expect(context_manager.get_context).to eq(shop_id: :expected_shop_id)
    end
  end

  describe "#set_context" do
    it "sets context" do
      context_manager.set_context(shop_id: :expected_shop_id)
      expect(context_manager.get_context).to eq(shop_id: :expected_shop_id)
    end

    it "merges context" do
      context_manager.set_context(shop_id: :expected_shop_id)
      context_manager.set_context(api_client_id: :expected_api_client_id)
      expect(context_manager.get_context).to eq(shop_id: :expected_shop_id, api_client_id: :expected_api_client_id)
    end

    it "overwrites existing keys" do
      context_manager.set_context(shop_id: :old_shop_id)
      context_manager.set_context(shop_id: :new_shop_id)
      expect(context_manager.get_context).to eq(shop_id: :new_shop_id)
    end

    it "returns empty hash by default" do
      expect(context_manager.get_context).to eq({})
    end
  end

  describe "local context with block" do
    it "isolates context inside block" do
      context_manager.set_context(shop_id: :global_shop_id)

      local_context = nil
      context_manager.set_context(api_client_id: :local_api_client_id) do
        local_context = context_manager.get_context
      end

      expect(local_context).to eq(shop_id: :global_shop_id, api_client_id: :local_api_client_id)
      expect(context_manager.get_context).to eq(shop_id: :global_shop_id)
    end

    it "supports nested local contexts" do
      context_manager.set_context(shop_id: :global_shop_id)

      level_1_context = nil
      level_2_context = nil
      context_manager.set_context(api_client_id: :level_1_api_client_id) do
        context_manager.set_context(user_id: :level_2_user_id) do
          level_2_context = context_manager.get_context
        end
        level_1_context = context_manager.get_context
      end

      expect(level_1_context).to eq(shop_id: :global_shop_id, api_client_id: :level_1_api_client_id)
      expect(level_2_context).to eq(shop_id: :global_shop_id, api_client_id: :level_1_api_client_id, user_id: :level_2_user_id)
      expect(context_manager.get_context).to eq(shop_id: :global_shop_id)
    end

    it "overrides global context inside the block" do
      context_manager.set_context(shop_id: :global_shop_id)

      local_context = nil
      context_manager.set_context(shop_id: :local_shop_id) do
        local_context = context_manager.get_context
      end

      expect(local_context).to eq(shop_id: :local_shop_id)
      expect(context_manager.get_context).to eq(shop_id: :global_shop_id)
    end

    it "localizes global context inside the block" do
      context_manager.set_context(shop_id: :global_shop_id)

      local_context = nil
      context_manager.set_context(shop_id: :local_shop_id) do
        context_manager.set_context(user_id: :global_user_id)
        local_context = context_manager.get_context
      end

      expect(local_context).to eq(shop_id: :local_shop_id, user_id: :global_user_id)
      expect(context_manager.get_context).to eq(shop_id: :global_shop_id)
    end
  end

  describe "#clear" do
    it "clears all context" do
      context_manager.set_context(shop_id: :expected_shop_id)
      context_manager.clear
      expect(context_manager.get_context).to eq({})
    end
  end

  describe "fiber isolation" do
    it "child fiber inherits parent context" do
      context_manager.set_context(shop_id: :parent_shop_id)

      child_context = nil
      Fiber.new { child_context = context_manager.get_context }.resume

      expect(child_context).to eq(shop_id: :parent_shop_id)
    end

    it "child fiber mutations don't affect parent" do
      context_manager.set_context(shop_id: :parent_shop_id)

      Fiber.new do
        context_manager.set_context(shop_id: :child_shop_id)
      end.resume

      expect(context_manager.get_context).to eq(shop_id: :parent_shop_id)
    end

    it "isolates context set after fiber creation" do
      context_manager.set_context(shop_id: :initial_shop_id)

      fiber = Fiber.new do
        context_manager.get_context
      end

      context_manager.set_context(api_client_id: :later_api_client_id)
      child_context = fiber.resume

      # Child sees context at fiber creation time, not the later update
      expect(child_context).to eq(shop_id: :initial_shop_id)
      expect(context_manager.get_context).to eq(shop_id: :initial_shop_id, api_client_id: :later_api_client_id)
    end
  end

  describe "thread isolation" do
    it "isolates context between threads" do
      context_manager.set_context(shop_id: :main_thread_shop_id)

      thread_context = nil
      thread = Thread.new do
        context_manager.set_context(shop_id: :other_thread_shop_id)
        thread_context = context_manager.get_context
      end
      thread.join

      expect(thread_context).to eq(shop_id: :other_thread_shop_id)
      expect(context_manager.get_context).to eq(shop_id: :main_thread_shop_id)
    end
  end
end

RSpec.describe Honeybadger::ErrorContext do
  it "inherits from AbstractContext" do
    expect(described_class).to be_a(Honeybadger::ContextManager)
  end

  it "implements #context_key" do
    expect(described_class.context_key).to eq(:__hb_error_context)
  end
end

RSpec.describe Honeybadger::EventContext do
  it "inherits from AbstractContext" do
    expect(described_class).to be_a(Honeybadger::ContextManager)
  end

  it "implements #context_key" do
    expect(described_class.context_key).to eq(:__hb_event_context)
  end
end

RSpec.describe Honeybadger::ExecutionContext do
  it "inherits from AbstractContext" do
    expect(described_class).to be_a(Honeybadger::ContextManager)
  end

  it "implements #context_key" do
    expect(described_class.context_key).to eq(:__hb_execution_context)
  end
end
