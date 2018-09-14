class CreateManualAdjustmentForEmployee
  def initialize(account, email)
    @account = account
    @email = email
  end

  def call
    params = {
      effective_at: Time.current,
      event_type: "adjustment_of_balances",
      employee: {
        id: employee.id,
        manager_id: nil,
      },
      employee_attributes: [
        {
          attribute_name: "adjustment",
          value: adjustment_value,
        },
      ],
    }

    Events::Adjustment::Create.new(params).call
    puts "Manual adjustment for #{@email} with value: #{adjustment_value} added"
  end

  private

  def employee
    @employee ||= @account.users.find_by!(email: @email).employee
  end

  def first_employee_time_off_policy
    @first_employee_time_of_policy ||=
      employee.employee_time_off_policies
        .joins(:time_off_category)
        .merge(TimeOffCategory.vacation)
        .order("effective_at asc")
        .first
  end

  def adjustment_value
    @adjustment_value ||=
      (first_employee_time_off_policy.time_off_policy.amount *
      first_employee_time_off_policy.occupation_rate).to_i
  end
end
