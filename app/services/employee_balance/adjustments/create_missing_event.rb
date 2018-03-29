class Adjustments::CreateMissingEvent
  pattr_initialize :balance

  delegate :employee, to: :balance

  def call
    return if employee_events_at_date(balance.employee, balance.effective_at).exists?
    employee.events.create!(
      event_type: "adjustment_of_balances",
      effective_at: balance.effective_at,
      employee_attribute_versions: [adjustment_amount_attribute]
    )
  end

  private

  def adjustment_amount_attribute
    Employee::AttributeVersion.new(
      employee: employee,
      attribute_definition: attribute_definition,
      value: balance.resource_amount
    )
  end

  def attribute_definition
    employee.account.employee_attribute_definitions.find_by!(name: "adjustment")
  end

  def employee_events_at_date(employee, effective_at)
    employee.events.where(event_type: :adjustment_of_balances, effective_at: effective_at)
  end
end
