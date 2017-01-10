class FindEmployeeBalancesToUpdate
  attr_reader :resource, :options, :effective_at, :related_balances, :amount

  def initialize(resource, options = {})
    @resource = resource
    @options = options
    @effective_at = earlier_date
    @related_balances = find_related_balances
    @amount = find_amount
  end

  def call
    return [resource.id] if resource.last_in_category? && resource.time_off_id.blank? &&
        options[:effective_at].blank?
    if options[:update_all] || options[:effective_at] || addition_destroyed?
      all_later_balances_ids
    else
      find_balances_by_policy
    end
  end

  private

  def find_amount
    if options[:resource_amount] || options[:manual_amount]
      new_amount = options[:resource_amount].to_i + options[:manual_amount].to_i

      return 0 if new_amount > resource.amount && new_amount <= 0
      new_amount - resource.amount
    else
      resource.amount
    end
  end

  def addition_destroyed?
    !Employee::Balance.exists?(resource.id) && resource.validity_date
  end

  def earlier_date
    [options[:effective_at], resource.effective_at, resource.time_off.try(:start_time)]
      .compact.map(&:to_time).min
  end

  def find_balances_by_policy
    resource.time_off_policy.counter? ? find_ids_for_counter : find_ids_for_balancer
  end

  def all_later_balances_ids
    related_balances.where('effective_at >= ?', effective_at).pluck(:id)
  end

  def find_ids_for_counter
    return all_later_balances_ids if resource.current_or_next_period ||
        options.delete(:update_all) ||
        next_addition.nil?
    related_balances.where(effective_at: effective_at..next_addition.effective_at).pluck(:id)
  end

  def find_ids_for_balancer
    no_removals_or_removals_bigger_than_amount? ? all_later_balances_ids : ids_to_removal
  end

  def find_related_balances
    RelativeEmployeeBalancesFinder.new(resource).balances_related_by_category_and_employee
  end

  def next_addition
    related_balances.additions.where('effective_at > ?', effective_at).order(:effective_at).first
  end

  def no_removals_or_removals_bigger_than_amount?
    amounts_bigger_than_zero? && resource.validity_date.blank? ||
      next_removals_smaller_than_amount? || active_balances_with_removals.blank?
  end

  def amounts_bigger_than_zero?
    options[:resource_amount].to_i + options[:manual_amount].to_i > 0
  end

  def active_balances_with_removals
    related_balances
      .where(
        'effective_at < ? AND validity_date > ? AND balance_credit_removal_id IS NOT NULL',
        effective_at, effective_at
      )
  end

  def next_removals_smaller_than_amount?
    return true unless active_balances_with_removals.present?
    active_balances_with_removals.map(&:amount).sum < amount.try(:abs).to_i
  end

  def ids_to_removal
    removals =
      related_balances
      .where(id: active_balances_with_removals.pluck(:balance_credit_removal_id).uniq)
      .order(effective_at: :asc)

    operation_amount = amount
    ids_till_removal = []

    removals.each do |removal|
      if removal.amount.abs >= operation_amount.abs
        ids_till_removal = related_balances.where(effective_at: effective_at..removal.effective_at)
                                           .pluck(:id)
      end
      operation_amount -= removal.amount
    end
    ids_till_removal.present? ? ids_till_removal : all_later_balances_ids
  end
end
