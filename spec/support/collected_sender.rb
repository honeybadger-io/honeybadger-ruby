class CollectingSender
  attr_reader :collected

  def initialize
    @collected = []
  end

  def send_to_honeybadger(notice)
    data = notice.respond_to?(:to_json) ? notice.to_json : notice
    @collected << data
  end
end
