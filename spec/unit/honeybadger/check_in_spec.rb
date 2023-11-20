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
end