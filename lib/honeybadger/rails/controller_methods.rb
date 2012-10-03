module Honeybadger
  module Rails
    module ControllerMethods
      def honeybadger_request_data
        { :parameters       => honeybadger_filter_if_filtering(params.to_hash),
          :session_data     => honeybadger_filter_if_filtering(honeybadger_session_data),
          :controller       => params[:controller],
          :action           => params[:action],
          :url              => honeybadger_request_url,
          :cgi_data         => honeybadger_filter_if_filtering(request.env) }
      end

      private

      # This method should be used for sending manual notifications while you are still
      # inside the controller. Otherwise it works like Honeybadger.notify.
      def notify_honeybadger(hash_or_exception)
        unless honeybadger_local_request?
          Honeybadger.notify(hash_or_exception, honeybadger_request_data)
        end
      end

      def honeybadger_local_request?
        if defined?(::Rails.application.config)
          ::Rails.application.config.consider_all_requests_local || (request.local? && (!request.env["HTTP_X_FORWARDED_FOR"]))
        else
          consider_all_requests_local || (local_request? && (!request.env["HTTP_X_FORWARDED_FOR"]))
        end
      end

      def honeybadger_ignore_user_agent? #:nodoc:
        # Rails 1.2.6 doesn't have request.user_agent, so check for it here
        user_agent = request.respond_to?(:user_agent) ? request.user_agent : request.env["HTTP_USER_AGENT"]
        Honeybadger.configuration.ignore_user_agent.flatten.any? { |ua| ua === user_agent }
      end

      def honeybadger_filter_if_filtering(hash)
        return hash if ! hash.is_a?(Hash)

        if respond_to?(:filter_parameters) # Rails 2
          filter_parameters(hash)
        elsif defined?(ActionDispatch::Http::ParameterFilter) # Rails 3
          ActionDispatch::Http::ParameterFilter.new(::Rails.application.config.filter_parameters).filter(hash)
        else
          hash
        end rescue hash
      end

      def honeybadger_session_data
        if session.respond_to?(:to_hash)
          session.to_hash
        else
          session.data
        end
      end

      def honeybadger_request_url
        url = "#{request.protocol}#{request.host}"

        unless [80, 443].include?(request.port)
          url << ":#{request.port}"
        end

        url << request.fullpath
        url
      end
    end
  end
end
