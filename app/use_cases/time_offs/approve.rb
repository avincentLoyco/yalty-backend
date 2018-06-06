module TimeOffs
  class Approve < UseCase
    include SubjectObservable

    pattr_initialize :time_off

    def call
      return run_callback(:not_modified) if time_off.approved?

      run_callback(result, time_off)
    end

    private

    def result
      execute ? :success : :failure
    end

    def execute
      time_off.approve! do
        create_new_employee_balance
        notify_observers notification_type: :time_off_approved, resource: time_off
      end
    end

    def create_new_employee_balance
      CreateEmployeeBalance.call(
        time_off.time_off_category_id,
        time_off.employee_id,
        time_off.employee.account_id,
        time_off_id: time_off.id,
        balance_type: "time_off",
        resource_amount: time_off.balance,
        effective_at: time_off.end_time
      )
    end
  end
end
