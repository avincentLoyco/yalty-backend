module EmployeeBalanceUpdate
  def update_employee_balances(resource, attributes)
    update_balances_processed_flag(balances_to_update(resource))

    UpdateBalanceJob.perform_later(resource.id, attributes)
  end

  def update_balances_after_removed(resource)
    ids = balances_to_update(resource) - [resource.id, resource.balance_credit_removal.try(:id)]
    update_balances_processed_flag(ids)
    next_balance_id = resource.next_balance

    UpdateBalanceJob.perform_later(next_balance_id) if next_balance_id.present?
  end

  def balances_to_update(resource, effective_at = nil)
    return [resource.id] if resource.last_in_policy? && effective_at.blank?
    effective_at ? resource.all_later_ids(earlier_date(effective_at)) : resource.later_balances_ids
  end

  def earlier_date(effective_at)
    effective_at < resource.effective_at ? effective_at : resource.effective_at
  end

  def update_balances_processed_flag(ids)
    Employee::Balance.where(id: ids).update_all(beeing_processed: true)
  end
end
