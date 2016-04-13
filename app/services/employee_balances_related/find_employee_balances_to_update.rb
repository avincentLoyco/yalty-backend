class FindEmployeeBalancesToUpdate
  attr_reader :resource, :options, :effective_at, :related_balances, :amount

  def initialize(resource, options = {})
    @resource = resource
    @options = options
    @effective_at = earlier_date
    @related_balances = find_related_balances
    @amount = options[:amount] ? options[:amount] : resource.amount
  end

  def call
    return [resource.id] if resource.last_in_category? && options[:effective_at].blank?
    options[:effective_at] || addition_destroyed? ? all_later_balances_ids : find_balances_by_policy
  end

  private

  def addition_destroyed?
    !Employee::Balance.exists?(resource.id) && resource.validity_date
  end

  def earlier_date
    if options[:effective_at] && options[:effective_at] < resource.effective_at
      options[:effective_at]
    else
      resource.effective_at
    end
  end

  def find_balances_by_policy
    resource.time_off_policy.counter? ? find_ids_for_counter : find_ids_for_balancer
  end

  def all_later_balances_ids
    related_balances.where('effective_at >= ?', effective_at).pluck(:id)
  end

  def find_ids_for_counter
    return all_later_balances_ids if resource.current_or_next_period || options.delete(:update_all)
    related_balances.where(effective_at: effective_at..next_addition.effective_at).pluck(:id)
  end

  def find_ids_for_balancer
    no_removals_or_removals_bigger_than_amount? ? all_later_balances_ids : ids_to_removal
  end

  def next_addition
    related_balances.additions.where('effective_at > ?', effective_at).order(:effective_at).first
  end

  def find_related_balances
    Employee::Balance.employee_balances(resource.employee.id, resource.time_off_category_id)
  end

  def no_removals_or_removals_bigger_than_amount?
    resource.current_or_next_period && active_balances_with_removals.blank? ||
      active_balances_with_removals.blank? && resource.time_off_policy.end_date.blank? ||
      next_removals_smaller_than_amount?
  end

  def active_balances
    related_balances.where('effective_at < ? AND validity_date > ?', effective_at, effective_at)
  end

  def active_balances_with_removals
    return [] unless active_balances.present?
    balance_additions_ids = related_balances.where(
      balance_credit_addition_id: active_balances.pluck(:id)).pluck(:balance_credit_addition_id)
    related_balances.where(id: balance_additions_ids)
  end

  def next_removals_smaller_than_amount?
    return true unless active_balances_with_removals.present?
    active_balances_with_removals.pluck(:amount).sum < amount.try(:abs).to_i
  end

  def ids_to_removal
    removals = related_balances.where(balance_credit_addition_id: active_balances.pluck(:id))
                               .order(effective_at: :asc)
    operation_amount = amount

    removals.each do |removal|
      if removal.amount.abs >= operation_amount.abs
        return related_balances.where(effective_at: effective_at..removal.effective_at).pluck(:id)
      end
      operation_amount -= removal.amount
    end
  end
end
