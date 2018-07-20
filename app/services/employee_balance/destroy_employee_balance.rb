class DestroyEmployeeBalance
  attr_reader :balances, :update, :removals

  method_object :balance, [:update]

  def initialize(balance, update: true)
    @balances = balance.respond_to?(:map) ? balance : [balance]
    @update = update
  end

  def call
    return unless balances.any?
    @removals = balances.map(&:balance_credit_removal).uniq.compact
    balances.map(&:destroy!)
    destroy_removals
    update_dependent_balances
  end

  private

  def destroy_removals
    return unless removals.present?
    removals.each do |removal|
      removal.destroy! if removal.balance_credit_additions.blank?
    end
  end

  def update_dependent_balances
    return unless update
    oldest_balance = balances.min_by(&:effective_at)
    next_affected_balance = find_next_affected_balance(oldest_balance)
    return unless next_affected_balance.present?
    PrepareEmployeeBalancesToUpdate.new(next_affected_balance, update_all: true).call
    ActiveRecord::Base.after_transaction do
      UpdateBalanceJob.perform_later(next_affected_balance.id, update_all: true)
    end
  end

  def find_next_affected_balance(oldest_balance)
    oldest_balance
      .employee
      .employee_balances
      .where(time_off_category: oldest_balance.time_off_category)
      .where("effective_at >= ?", date_for_balance_type(oldest_balance))
      .order(:effective_at).first
  end

  def date_for_balance_type(oldest_balance)
    if oldest_balance.balance_type.eql?("time_off")
      oldest_balance.time_off.start_time
    else
      oldest_balance.effective_at
    end
  end
end
