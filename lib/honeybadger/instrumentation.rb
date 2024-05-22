require 'honeybadger/histogram'
require 'honeybadger/timer'
require 'honeybadger/counter'
require 'honeybadger/gauge'

module Honeybadger
  # +Honeybadger::Instrumentation+ defines the API for collecting metric data from anywhere
  # in an application. These class methods may be used directly, or from the Honeybadger singleton
  # instance..
  #
  # @example
  #
  # class TicketsController < ApplicationController
  #   def create
  #     Honeybadger.time('create.ticket', ->{
  #       Ticket.create(params[:ticket])
  #     })
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

    def self.time(name, attributes: {}, duration: nil)
      if block_given?
        duration = monotonic_timer{ yield }[0]
      end

      raise 'No duration found' if duration.nil?

      Honeybadger::Timer.register(name, attributes).tap do |timer|
        timer.record(duration)
      end
    end

    def self.histogram(name, attributes: {}, duration: nil)
      if block_given?
        duration = monotonic_timer{ yield }[0]
      end

      raise 'No duration found' if duration.nil?

      Honeybadger::Histogram.register(name, attributes).tap do |histogram|
        histogram.record(duration)
      end
    end

    def self.increment_counter(name, count: 1, attributes: {})
      Honeybadger::Counter.register(name, attributes).tap do |counter|
        counter.count(count)
      end
    end

    def self.gauge(name, value:, attributes: {})
      Honeybadger::Gauge.register(name, attributes).tap do |gauge|
        gauge.record(value)
      end
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
  #     time 'create.ticket', ->{
  #       Ticket.create(params[:ticket])
  #     }
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
      body = args.select { |a| a.respond_to?(:call) }.first
      if body
        Honeybadger::Instrumentation.time(name, attributes: attributes) { body.call }
      elsif attributes.keys.include?(:duration)
        Honeybadger::Instrumentation.time(name, attributes: attributes, duration: attributes.delete(:duration))
      end
    end

    def histogram(name, *args)
      attributes = extract_attributes(args)
      body = args.select { |a| a.respond_to?(:call) }.first
      if body
        Honeybadger::Instrumentation.histogram(name, attributes: attributes) { body.call }
      elsif attributes.keys.include?(:duration)
        Honeybadger::Instrumentation.histogram(name, attributes: attributes, duration: attributes.delete(:duration))
      end
    end

    def increment_counter(name, *args)
      attributes = extract_attributes(args)
      count = args.select { |a| a.respond_to?(:call) }.first&.call || 1
      Honeybadger::Instrumentation.increment_counter(name, count: count, attributes: attributes)
    end

    def gauge(name, *args)
      attributes = extract_attributes(args)
      value = args.select { |a| a.respond_to?(:call) }.first.call
      Honeybadger::Instrumentation.gauge(name, value: value, attributes: attributes)
    end

    # @api private
    def extract_attributes(args)
      attributes = args.select { |a| a.is_a?(Hash) }.first || {}
      attributes.merge(metric_source: @metric_source).merge(@metric_attributes || {}).compact
    end
  end
end

