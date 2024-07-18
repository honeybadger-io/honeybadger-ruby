require 'forwardable'

module Honeybadger
  class Event
    extend Forwardable

    # The timestamp of the event
    attr_reader :ts

    # The event_type of the event
    attr_reader :event_type

    # The payload data of the event
    attr_reader :payload

    def_delegators :payload, :dig, :[], :[]=

    # @api private
    def initialize(event_type_or_payload, payload={})
      if event_type_or_payload.is_a?(String)
        @event_type = event_type_or_payload
        @payload = payload
      elsif event_type_or_payload.is_a?(Hash)
        @event_type = event_type_or_payload[:event_type] || event_type_or_payload["event_type"]
        @payload = event_type_or_payload
      end

      @ts = payload[:ts] || Time.now.utc.strftime("%FT%T.%LZ")
      @halted = false
    end

    # Halts the event and the before_event callback chain.
    #
    # Returns nothing.
    def halt!
      @halted ||= true
    end

    # @api private
    # Determines if this event will be discarded.
    def halted?
      !!@halted
    end

    # @api private
    # Template used to create JSON payload.
    #
    # @return [Hash] JSON representation of the event.
    def as_json(*args)
      payload.tap do |p|
        p[:ts] = ts
        p[:event_type] = event_type if event_type
      end
    end
  end
end
