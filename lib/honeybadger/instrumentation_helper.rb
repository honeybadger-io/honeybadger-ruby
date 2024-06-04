require 'honeybadger/instrumentation'

module Honeybadger
  # +Honeybadger::InstrumentationHelper+ is a module that can be included into any class. This module
  # provides a convenient DSL around the instrumentation methods to prvoide a cleaner interface.
  # There are three usage variations as show in the example below:
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

    # returns two parameters, the first is the duration of the execution, and the second is
    # the return value of the passed block
    def monotonic_timer
      metric_instrumentation.monotonic_timer { yield }
    end

    def metric_source(source)
      @metric_source = source
    end

    def metric_agent(agent)
      @metric_agent = agent
    end

    def metric_instrumentation
      @metric_instrumentation ||= @metric_agent ? Honeybadger::Instrumentation.new(@metric_agent) : Honeybadger.instrumentation
    end

    def metric_attributes(attributes)
      raise "metric_attributes expects a hash" unless attributes.is_a?(Hash)
      @metric_attributes = attributes
    end

    def time(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      if callable
        metric_instrumentation.time(name, attributes, ->{ callable.call })
      elsif block_given?
        metric_instrumentation.time(name, attributes, ->{ yield })
      elsif attributes.keys.include?(:duration)
        metric_instrumentation.time(name, attributes)
      end
    end

    def histogram(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      if callable
        metric_instrumentation.histogram(name, attributes, ->{ callable.call })
      elsif block_given?
        metric_instrumentation.histogram(name, attributes, ->{ yield })
      elsif attributes.keys.include?(:duration)
        metric_instrumentation.histogram(name, attributes)
      end
    end

    def increment_counter(name, *args)
      attributes = extract_attributes(args)
      by = extract_callable(args)&.call || attributes.delete(:by) || 1
      if block_given?
        metric_instrumentation.increment_counter(name, attributes, ->{ yield })
      else
        metric_instrumentation.increment_counter(name, attributes.merge(by: by))
      end
    end

    def decrement_counter(name, *args)
      attributes = extract_attributes(args)
      by = extract_callable(args)&.call || attributes.delete(:by) || 1
      if block_given?
        metric_instrumentation.decrement_counter(name, attributes, ->{ yield })
      else
        metric_instrumentation.decrement_counter(name, attributes.merge(by: by))
      end
    end

    def gauge(name, *args)
      attributes = extract_attributes(args)
      value = extract_callable(args)&.call || attributes.delete(:value)
      if block_given?
        metric_instrumentation.gauge(name, attributes, ->{ yield })
      else
        metric_instrumentation.gauge(name, attributes.merge(value: value))
      end
    end

    # @api private
    def extract_attributes(args)
      attributes = metric_instrumentation.extract_attributes(args)
      attributes.merge(metric_source: @metric_source).merge(@metric_attributes || {}).compact
    end

    # @api private
    def extract_callable(args)
      metric_instrumentation.extract_callable(args)
    end
  end
end
