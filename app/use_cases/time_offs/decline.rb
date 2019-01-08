# TODO: refactor this class to use dependency injection

module TimeOffs
  class Decline < UseCase
    include SubjectObservable

    pattr_initialize :time_off

    include ActiveSupport::Configurable

    config_accessor :balance_destroyer do
      DestroyEmployeeBalance
    end

    def call
      return run_callback(:not_modified) if time_off.declined?
      time_off.decline! do
        balance_destroyer.call(time_off.employee_balance)
        notify_observers notification_type: :time_off_declined, resource: time_off
      end
      run_callback(:success)
    end
  end
end
