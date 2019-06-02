module Honeybadger
  module Breadcrumbs
    class ActiveSupport
      def self.default_notifications
        {
          # ActiveRecord Actions
          #
          "sql.active_record" => {
            message: "Active Record SQL",
            category: :query,
            exclude_when: lambda do |data|
              # Ignore schema, begin, and commit transaction queries
              data[:name] == "SCHEMA" || data[:sql].match?(/^(begin|commit) transaction$/)
            end
          },

          # ActionCable Actions
          #
          "perform_action.action_cable" => {
            message: "Action Cable Perform Action",
            category: :render
          },

          # ActiveJob Actions
          #
          "enqueue.active_job" => {
            message: "Active Job Enqueue",
            category: :job
          },
          "perform_start.active_job" => {
            message: "Active Job Perform Start",
            category: :job,
          },

          # ActiveSupport Actions
          #
          "cache_read.active_support" => {
            message: "Active Support Cache Read",
            category: :query
          },
          "cache_fetch_hit.active_support" => {
            message: "Active Support Cache Fetch Hit",
            category: :query
          },

          # Controller Actions
          #
          "halted_callback.action_controller" => {
            message: "Action Controller Callback Halted",
            category: :request,
          },
          "process_action.action_controller" => {
            message: "Action Controller Action Process",
            category: :request,
          },
          "redirect_to.action_controller" => {
            message: "Action Controller Redirect",
            category: :request,
          },

          # View Actions
          #
          "render_template.action_view" => {
            message: "Action View Template Render",
            category: :render,
          },
          "render_partial.action_view" => {
            message: "Action View Partial Render",
            category: :render,
          },

          # Mailer actions
          #
          "deliver.action_mailer" => {
            message: "Action Mailer Deliver",
            transform: lambda do |data|
              data.slice(:mailer, :message_id, :from, :date)
            end,
            category: :render
          }
        }
      end
    end
  end
end
