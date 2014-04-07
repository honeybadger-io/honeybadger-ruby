class Net::HTTP
  def request_with_honeybadger(*args, &block)
    request = args[0]
    uri = request.path.match(%r{https?://}) ? URI(request.path) : URI("http#{use_ssl? ? 's' : ''}://#{address}:#{port}#{request.path}")

    if uri.host.match("honeybadger.io")
      return request_without_honeybadger(*args, &block)
    end

    ActiveSupport::Notifications.instrument("net_http.request", { uri: uri, method: request.method }) do
      request_without_honeybadger(*args, &block)
    end
  end

  alias request_without_honeybadger request
  alias request request_with_honeybadger
end
