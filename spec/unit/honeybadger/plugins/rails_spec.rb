begin
  require "rails"
  RAILS_PRESENT = true
rescue LoadError
  RAILS_PRESENT = false
end

if RAILS_PRESENT
  require "honeybadger"
  require "honeybadger/plugins/rails"

  describe "Rails notification subscriptions" do
    context "ActiveRecord" do
      subject { Honeybadger::ActiveRecordSubscriber.new }

      it "sanitizes SQL" do
        subject.sanitize_query("SELECT * FROM users WHERE name = 'foo'").should == "SELECT * FROM users WHERE name = '?'"
      end

      it "sanitizes SQL with double quotes" do
        subject.sanitize_query('SELECT * FROM users WHERE name = "foo"').should == 'SELECT * FROM users WHERE name = "?"'
      end

      it "sanitizes SQL with numbers" do
        subject.sanitize_query("SELECT * FROM users WHERE id = 1").should == "SELECT * FROM users WHERE id = ?"
      end

      it "sanitizes SQL with floats" do
        subject.sanitize_query("SELECT * FROM users WHERE id = 1.0").should == "SELECT * FROM users WHERE id = ?"
      end

      it "sanitizes SQL with multiple values" do
        subject.sanitize_query("SELECT * FROM users WHERE id = 1 AND name = 'foo' LIMIT 1").should == "SELECT * FROM users WHERE id = ? AND name = '?' LIMIT ?"
      end

      it "handles double-quoted strings" do
        subject.sanitize_query(%(SELECT * FROM "users" WHERE name = 'foo'), "postgres").should == %(SELECT * FROM "users" WHERE name = '?')
      end
    end
  end
end
