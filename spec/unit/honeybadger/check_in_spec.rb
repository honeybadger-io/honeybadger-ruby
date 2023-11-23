require 'honeybadger/check_in'

describe Honeybadger::CheckIn do
  it "should set default values for required fields for simple checkin" do
    check_in = described_class.new("1234", id: "5678", attributes: {})
    parsed = JSON.parse(check_in.to_json)
    expect(parsed["slug"]).to eq("")
    expect(parsed["grace_period"]).to eq("")
  end

  it "should set default values for required fields for cron checkin" do
    check_in = described_class.new("1234", id: "5678", attributes: {"schedule_type" => "cron"})
    parsed = JSON.parse(check_in.to_json)
    expect(parsed["slug"]).to eq("")
    expect(parsed["grace_period"]).to eq("")
    expect(parsed["cron_timezone"]).to eq("")
  end

  it "should properly serialize simple check in" do
    input = {
      "name" => "check in",
      "slug" => "check_in",
      "schedule_type" => "simple",
      "report_period" => "1 day",
      "grace_period" => "1 day"
    }
    check_in = described_class.new("1234", id: "5678", attributes: input)
    parsed = JSON.parse(check_in.to_json)
    parsed.reject {|k,v| k == 'id'}
    expect(parsed).to eq(input)    
  end

  it "should properly serialize simple check in" do
    input = {
      "name" => "check in",
      "slug" => "check_in",
      "schedule_type" => "cron",
      "cron_schedule" => "*/5 * * * *",
      "cron_timezone" => "",
      "grace_period" => "1 day"
    }
    check_in = described_class.new("1234", id: "5678", attributes: input)
    parsed = JSON.parse(check_in.to_json)
    parsed.reject {|k,v| k == 'id'}
    expect(parsed).to eq(input)    
  end
end