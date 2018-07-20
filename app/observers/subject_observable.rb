# frozen_string_literal: true

module SubjectObservable
  def observers
    @observers ||= []
  end

  def add_observer(*new_observers)
    new_observers.each do |observer|
      unless observer.respond_to? :update
        raise NoMethodError, "observer must implement update method"
      end
      observers << observer
    end

    self
  end

  def delete_observer(observer)
    observers.delete(observer)

    self
  end

  def notify_observers(*args, **keyword_args)
    observers.each do |observer|
      observer.update(*args, **keyword_args)
    end
  end

  alias add_observers add_observer
end
