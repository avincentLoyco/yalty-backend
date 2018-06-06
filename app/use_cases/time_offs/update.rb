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
        update_approval_status
        update_time_off
      end

      run_callback(:success)
    end

    private

    attr_reader :time_off, :attributes, :previous_start_time

    def update_time_off
      time_off.assign_attributes(attributes.except(:approval_status))

      return unless time_off.changed?
      time_off.save!
      update_balance
    end

    def update_approval_status
      submit_approve if approved?
      submit_decline if declined?
    end

    def submit_approve
      Approve.call(time_off) do |approve|
        approve.add_observers(*observers)
      end
    end

    def submit_decline
      Decline.call(time_off) do |decline|
        decline.add_observers(*observers)
      end
    end

    def approved?
      attributes[:approval_status] == "approved"
    end

    def declined?
      attributes[:approval_status] == "declined"
    end

    def balance_attributes
      @balance_attributes ||=
        {
          resource_amount: time_off.balance,
          effective_at: previous_start_time.to_s,
        }
    end

    def update_balance
      return unless approved?

      time_off.reload
      PrepareEmployeeBalancesToUpdate.call(employee_balance, balance_attributes)
      UpdateBalanceJob.perform_later(employee_balance.id, balance_attributes)
    end
  end
end
