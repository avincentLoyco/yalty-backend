# frozen_string_literal: true

class UseCase
  attr_implement :call

  class << self
    def call(*args)
      new(*args).tap do |instance|
        yield(instance) if block_given?
        return instance.call
      end
    end
  end

  def on(name, &callback)
    callbacks[name.to_sym] = callback

    self
  end

  private

  def callbacks
    @callbacks ||= {}
  end

  def run_callback(name, *args)
    callbacks[name].call(*args) if callbacks.key?(name.to_sym)
  end
end
