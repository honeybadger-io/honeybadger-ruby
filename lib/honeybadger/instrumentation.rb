require 'honeybadger/histogram'
require 'honeybadger/timer'
require 'honeybadger/counter'
require 'honeybadger/gauge'

module Honeybadger
  # +Honeybadger::Instrumentation+ defines the API for collecting metric data from anywhere
  # in an application. These class methods may be used directly, or from the Honeybadger singleton
  # instance. There are three usage variations as show in the example below:
  #
  # @example
  #   class TicketsController < ApplicationController
  #     def create
  #       # pass a block
  #       Honeybadger.time('create.ticket') { Ticket.create(params[:ticket]) }
  #
  #       # pass a lambda argument
  #       Honeybadger.time 'create.ticket', ->{ Ticket.create(params[:ticket]) }
  #
  #       # pass the duration argument
  #       duration = timing_method { Ticket.create(params[:ticket]) }
  #       Honeybadger.time 'create.ticket', duration: duration
  #     end
  #   end
  #
  #
  class Instrumentation
    attr_reader :agent

    def initialize(agent)
      @agent = agent
    end

    def registry
      agent.registry
    end

    # returns two parameters, the first is the duration of the execution, and the second is
    # the return value of the passed block
    def monotonic_timer
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      result = yield
      finish_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      [((finish_time - start_time) * 1000).round(2), result]
    end

    def time(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      value = nil

      if callable
        value = monotonic_timer{ callable.call }[0]
      elsif block_given?
        value = monotonic_timer{ yield }[0]
      else
        value = attributes.delete(:duration) || attributes.delete(:value)
      end

      Honeybadger::Timer.register(registry, name, attributes).tap do |timer|
        if value.nil?
          agent.config.logger.warn("No value found for timer #{name}. Must specify either duration or value. Skipping.")
        else
          timer.record(value)
        end
      end
    end

    def histogram(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      value = nil

      if callable
        value = monotonic_timer{ callable.call }[0]
      elsif block_given?
        value = monotonic_timer{ yield }[0]
      else
        value = attributes.delete(:duration) || attributes.delete(:value)
      end

      Honeybadger::Histogram.register(registry, name, attributes).tap do |histogram|
        if value.nil?
          agent.config.logger.warn("No value found for histogram #{name}. Must specify either duration or value. Skipping.")
        else
          histogram.record(value)
        end
      end
    end

    def increment_counter(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      value = nil

      if callable
        value = callable.call
      elsif block_given?
        value = yield
      else
        value = attributes.delete(:by) || attributes.delete(:value) || 1
      end

      Honeybadger::Counter.register(registry, name, attributes).tap do |counter|
        counter.count(value)
      end
    end

    def decrement_counter(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      value = nil

      if callable
        value = callable.call
      elsif block_given?
        value = yield
      else
        value = attributes.delete(:by) || attributes.delete(:value) || 1
      end

      Honeybadger::Counter.register(registry, name, attributes).tap do |counter|
        counter.count(value * -1)
      end
    end

    def gauge(name, *args)
      attributes = extract_attributes(args)
      callable = extract_callable(args)
      value = nil

      if callable
        value = callable.call
      elsif block_given?
        value = yield
      else
        value = attributes.delete(:duration) || attributes.delete(:value)
      end

      Honeybadger::Gauge.register(registry, name, attributes).tap do |gauge|
        if value.nil?
          agent.config.logger.warn("No value found for gauge #{name}. Must specify value. Skipping.")
        else
          gauge.record(value)
        end
      end
    end

    # @api private
    def extract_attributes(args)
      args.select { |a| a.is_a?(Hash) }.first || {}
    end

    # @api private
    def extract_callable(args)
      args.select { |a| a.respond_to?(:call) }.first
    end
  end
end
