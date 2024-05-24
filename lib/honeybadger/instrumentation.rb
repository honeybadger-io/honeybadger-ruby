require 'honeybadger/histogram'
require 'honeybadger/timer'
require 'honeybadger/counter'
require 'honeybadger/gauge'

module Honeybadger
  # +Honeybadger::Instrumentation+ defines the API for collecting metric data from anywhere
  # in an application. These class methods may be used directly, or from the Honeybadger singleton
  # instance.
  #
  # @example
  #
  # class TicketsController < ApplicationController
  #   def create
  #     # pass a block
  #     Honeybadger.time('create.ticket') { Ticket.create(params[:ticket]) }
  #
  #     # pass a lambda argument
  #     Honeybadger.time 'create.ticket', ->{ Ticket.create(params[:ticket]) }
  #
  #     # pass the duration argument
  #     duration = timing_method { Ticket.create(params[:ticket]) }
  #     Honeybadger.time 'create.ticket', duration: duration
  #   end
  # end
  #
  #
  class Instrumentation
    def self.monotonic_timer
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      result = yield
      finish_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      [((finish_time - start_time) * 1000).round(2), result]
    end

    def self.time(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      duration = attributes.delete(:duration)

      if callable
        duration = monotonic_timer{ callable.call }[0]
      elsif block_given?
        duration = monotonic_timer{ yield }[0]
      end

      raise 'No duration found' if duration.nil?

      Honeybadger::Timer.register(name, attributes).tap do |timer|
        timer.record(duration)
      end
    end

    def self.histogram(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      duration = attributes.delete(:duration)

      if callable
        duration = monotonic_timer{ callable.call }[0]
      elsif block_given?
        duration = monotonic_timer{ yield }[0]
      end

      raise 'No duration found' if duration.nil?

      Honeybadger::Histogram.register(name, attributes).tap do |histogram|
        histogram.record(duration)
      end
    end

    def self.increment_counter(name, *args)
      attributes = extract_attributes(args)
      by = extract_callable(args)&.call || attributes.delete(:by) || 1

      Honeybadger::Counter.register(name, attributes).tap do |counter|
        counter.count(by)
      end
    end

    def self.decrement_counter(name, *args)
      attributes = extract_attributes(args)
      by = extract_callable(args)&.call || attributes.delete(:by) || 1

      Honeybadger::Counter.register(name, attributes).tap do |counter|
        counter.count(by * -1)
      end
    end

    def self.gauge(name, *args)
      attributes = extract_attributes(args)
      value = extract_callable(args)&.call || attributes.delete(:value)

      Honeybadger::Gauge.register(name, attributes).tap do |gauge|
        gauge.record(value)
      end
    end

    # @api private
    def self.extract_attributes(args)
      args.select { |a| a.is_a?(Hash) }.first || {}
    end

    # @api private
    def self.extract_callable(args)
      args.select { |a| a.respond_to?(:call) }.first
    end
  end

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

