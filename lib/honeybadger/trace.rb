require 'securerandom'

require 'honeybadger/agent'
require 'honeybadger/util/sanitizer'

module Honeybadger
  class Trace
    attr_reader :id, :duration, :key

    def self.current
      Thread.current[:__hb_trace]
    end

    def self.create(id)
      Thread.current[:__hb_trace] = new(id)
    end

    def self.instrument(key, payload = {}, &block)
      current = self.current
      self.create(SecureRandom.uuid).instrument(key, payload, &block)
    ensure
      Thread.current[:__hb_trace] = current
    end

    # Internal: Disables event tracing for executed code block.
    #
    # block - The code which should not be traced.
    #
    # Returns the return value from the block.
    def self.ignore_events
      return yield if ignoring_events?

      begin
        Thread.current[:__hb_ignore_trace_events] = true
        yield
      ensure
        Thread.current[:__hb_ignore_trace_events] = false
      end
    end

    # Internal: Is event tracing currently disabled?
    def self.ignoring_events?
      !!Thread.current[:__hb_ignore_trace_events]
    end

    def initialize(id)
      @id = id
      @events = []
      @meta = {}
      @fast_queries = {}
      @duration = 0
    end

    def add(event)
      return if ignoring_events?
      ce = clean_event(event)
      @events << ce.to_a if ce.render?
    end

    def add_query(event)
      return if ignoring_events?
      return add(event) unless event.duration < 6

      ce = clean_event(event)
      return unless ce.render?
      query = ce.to_s
      if @fast_queries[query]
        @fast_queries[query][:duration] += ce.event.duration
        @fast_queries[query][:count] += 1
      else
        @fast_queries[query] = { :duration => ce.event.duration, :count => 1 }
      end
    end

    def complete(event, payload = {})
      @meta = clean_event(event).to_h.merge(payload)
      @duration = event.duration
      @key = "#{event.payload[:controller]}##{event.payload[:action]}"
      Thread.current[:__hb_trace] = nil
      Agent.trace(self)
    end

    def instrument(key, payload)
      @key = key
      @meta = payload
      started = Time.now
      yield
    rescue Exception => e
      @meta[:exception] = [e.class.name, e.message]
      raise e
    ensure
      @meta.merge!(:duration => @duration = 1000.0 * (Time.now - started))
      Agent.trace(self)
    end

    def to_h
      @meta.merge({ :events => @events, :key => @key, :fast_queries => @fast_queries.map {|k,v| [ k, v[:duration], v[:count] ] } })
    end

    # Private helpers: use at your own risk.

    attr_reader :meta

    protected

    def ignoring_events?
      self.class.ignoring_events?
    end

    def clean_event(event)
      TraceCleaner.create(event)
    end

  end

  module TraceCleaner

    def self.create(event)
      Classes[event.name].new(event)
    end

    class Base
      attr_reader :event

      def initialize(event)
        @event = event
      end

      def render?
        true
      end

      def payload
        event.payload
      end

      def to_s
        payload[:path] || payload[:key] || payload.inspect
      end

      def to_h
        { :name => event.name, :desc => to_s, :duration => event.duration }
      end

      def to_a
        [ event.name, event.duration, to_s ]
      end

    end

    class NetHttpRequest < Base
      Replacement = "..."
      def to_s
        uri = payload[:uri]
        uri.user = Replacement if uri.user
        uri.password = Replacement if uri.password
        uri.query = Replacement if uri.query
        "#{payload[:method]} #{uri}"
      end
    end

    class ActiveRecord < Base
      Schema = "SCHEMA".freeze
      SchemaMigrations = /schema_migrations/.freeze
      EscapedQuotes = /(\\"|\\')/.freeze
      SQuotedData = /'(?:[^']|'')*'/.freeze
      DQuotedData = /"(?:[^"]|"")*"/.freeze
      NumericData = /\b\d+\b/.freeze
      Newline = /\n/.freeze
      Replacement = "?".freeze
      EmptyReplacement = "".freeze
      DoubleQuoters = /(postgres|sqlite|postgis)/.freeze

      def initialize(event)
        super
        @sql = Util::Sanitizer.sanitize_string(event.payload[:sql])
      end

      def render?
        event.payload[:name] != Schema && !sql.match(SchemaMigrations)
      end

      def to_s
        s = sql.dup
        s.gsub!(EscapedQuotes, EmptyReplacement)
        s.gsub!(SQuotedData, Replacement)
        s.gsub!(DQuotedData, Replacement) unless ::ActiveRecord::Base.connection_pool.spec.config[:adapter] =~ DoubleQuoters
        s.gsub!(NumericData, Replacement)
        s.gsub!(Newline, EmptyReplacement)
        s.squeeze!(' ')
        s
      end

      private
        attr_reader :sql
    end

    class ActionView < Base
      EmptyReplacement = "".freeze

      def to_s
        event.payload[:identifier].to_s.gsub(::Rails.root.to_s + '/', EmptyReplacement)
      end
    end

    class ActionController < Base
      def payload
        event.payload.reject {|k, v| k == :params }
      end

      def to_s
        payload.inspect
      end

      def to_h
        payload.merge({ :duration => event.duration })
      end
    end

    Classes = Hash.new(Base).merge({
      'sql.active_record' => ActiveRecord,
      'render_template.action_view' => ActionView,
      'render_partial.action_view' => ActionView,
      'render_collection.action_view' => ActionView,
      'process_action.action_controller' => ActionController,
      'net_http.request' => NetHttpRequest
    })
  end
end
