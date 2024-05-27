require 'honeybadger/instrumentation'

module Honeybadger
  # +Honeybadger::InstrumentationHelper+ is a module that can be included into any class. This module
  # provides a convenient DSL around the instrumentation methods to prvoide a cleaner interface.
  #
  # @example
  #
  # class TicketsController < ApplicationController
  #   include Honeybadger::InstrumentationHelper
  #
  #   def create
  #     metric_source 'controller'
  #     metric_attributes { foo: 'bar' } # These attributes get tagged to all metrics called after.
  #
  #     # pass a block
  #     time('create.ticket') { Ticket.create(params[:ticket]) }
  #
  #     # pass a lambda argument
  #     time 'create.ticket', ->{ Ticket.create(params[:ticket]) }
  #
  #     # pass the duration argument
  #     duration = timing_method { Ticket.create(params[:ticket]) }
  #     time 'create.ticket', duration: duration
  #   end
  # end
  #
  #
  module InstrumentationHelper
    def monotonic_timer
      Honeybadger::Instrumentation.monotonic_timer { yield }
    end

    def metric_source(source)
      @metric_source = source
    end

    def metric_attributes(attributes)
      raise "metric_attributes expects a hash" unless attributes.is_a?(Hash)
      @metric_attributes = attributes
    end

    def time(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      if callable
        Honeybadger::Instrumentation.time(name, attributes, ->{ callable.call })
      elsif block_given?
        Honeybadger::Instrumentation.histogram(name, attributes, ->{ yield })
      elsif attributes.keys.include?(:duration)
        Honeybadger::Instrumentation.time(name, attributes)
      end
    end

    def histogram(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      if callable
        Honeybadger::Instrumentation.histogram(name, attributes, ->{ callable.call })
      elsif block_given?
        Honeybadger::Instrumentation.histogram(name, attributes, ->{ yield })
      elsif attributes.keys.include?(:duration)
        Honeybadger::Instrumentation.histogram(name, attributes)
      end
    end

    def increment_counter(name, *args)
      attributes = extract_attributes(args)
      by = extract_callable(args)&.call || attributes.delete(:by) || 1
      if block_given?
        Honeybadger::Instrumentation.increment_counter(name, attributes, ->{ yield })
      else
        Honeybadger::Instrumentation.increment_counter(name, attributes.merge(by: by))
      end
    end

    def decrement_counter(name, *args)
      attributes = extract_attributes(args)
      by = extract_callable(args)&.call || attributes.delete(:by) || 1
      if block_given?
        Honeybadger::Instrumentation.decrement_counter(name, attributes, ->{ yield })
      else
        Honeybadger::Instrumentation.decrement_counter(name, attributes.merge(by: by))
      end
    end

    def gauge(name, *args)
      attributes = extract_attributes(args)
      value = extract_callable(args)&.call || attributes.delete(:value)
      if block_given?
        Honeybadger::Instrumentation.gauge(name, attributes, ->{ yield })
      else
        Honeybadger::Instrumentation.gauge(name, attributes.merge(value: value))
      end
    end

    # @api private
    def extract_attributes(args)
      attributes = Honeybadger::Instrumentation.extract_attributes(args)
      attributes.merge(metric_source: @metric_source).merge(@metric_attributes || {}).compact
    end

    # @api private
    def extract_callable(args)
      Honeybadger::Instrumentation.extract_callable(args)
    end
  end
end
