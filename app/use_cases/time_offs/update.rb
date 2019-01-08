# TODO: refactor this class to use dependency injection

module TimeOffs
  class Update < UseCase
    include SubjectObservable

    def initialize(time_off, attributes = {})
      @time_off = time_off
      @attributes = attributes
      @previous_start_time = time_off.start_time
    end

    delegate :employee_balance, to: :time_off

    def call
      TimeOff.transaction do
        time_off.assign_attributes(attributes)

        return unless time_off.changed?
        time_off.save!
        update_balance if time_off.approved?
      end

      run_callback(:success)
    end

    private

    attr_reader :time_off, :attributes, :previous_start_time

    def balance_attributes
      @balance_attributes ||=
        {
          resource_amount: time_off.balance,
          effective_at: previous_start_time.to_s,
        }
    end

    def update_balance
      time_off.reload
      PrepareEmployeeBalancesToUpdate.call(employee_balance, balance_attributes)
      UpdateBalanceJob.perform_later(employee_balance.id, balance_attributes)
    end
  end
end
