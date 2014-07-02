require 'net/http'
require 'uri'

# Capistrano tasks for notifying Honeybadger of deploys
module HoneybadgerTasks

  # Public: Alerts Honeybadger of a deploy.
  #
  # opts - Data about the deploy that is set to Honeybadger
  #        :api_key        - Api key of you Honeybadger application
  #        :environment    - Environment of the deploy (production, staging)
  #        :revision       - The given revision/sha that is being deployed
  #        :repository     - Address of your repository to help with code lookups
  #        :local_username - Who is deploying
  #
  # Returns true or false
  def self.deploy(opts = {})
    api_key = opts.delete(:api_key) || Honeybadger.configuration.api_key
    unless api_key =~ /\S/
      $stderr.puts "I don't seem to be configured with an API key.  Please check your configuration."
      return false
    end

    unless opts[:environment] =~ /\S/
      $stderr.puts "I don't know to which environment you are deploying (use the TO=production option)."
      return false
    end

    dry_run = opts.delete(:dry_run)
    params = {}
    opts.each {|k,v| params["deploy[#{k}]"] = v }

    host = Honeybadger.configuration.host || 'api.honeybadger.io'
    port = Honeybadger.configuration.port

    proxy = Net::HTTP.Proxy(Honeybadger.configuration.proxy_host,
                            Honeybadger.configuration.proxy_port,
                            Honeybadger.configuration.proxy_user,
                            Honeybadger.configuration.proxy_pass)
    http = proxy.new(host, port)

    # Handle Security
    if Honeybadger.configuration.secure?
      http.use_ssl      = true
      http.ca_file      = Honeybadger.configuration.ca_bundle_path
      http.verify_mode  = OpenSSL::SSL::VERIFY_PEER
    end

    post = Net::HTTP::Post.new("/v1/deploys")
    post.set_form_data(params)
    post['X-API-Key'] = api_key

    if dry_run
      puts http.inspect, params.inspect
      return true
    else
      response = http.request(post)

      if Net::HTTPSuccess === response
        puts "Successfully recorded deployment"
        return true
      else
        $stderr.puts "Error recording deployment: #{response.class} -- #{response.body || 'no response'}"
        return false
      end
    end
  end
end

