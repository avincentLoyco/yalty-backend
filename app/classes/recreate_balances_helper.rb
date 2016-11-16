class RecreateBalancesHelper
  attr_reader :new_effective_at, :old_effective_at, :time_off_category, :employee, :etop,
    :manual_amount

  def initialize(
    time_off_category_id:,
    employee_id:,
    manual_amount: 0,
    new_effective_at: nil,
    old_effective_at: nil,
    destroyed_effective_at: nil
  )

    @new_effective_at = new_effective_at || destroyed_effective_at
    @old_effective_at = old_effective_at || destroyed_effective_at
    @time_off_category = TimeOffCategory.find(time_off_category_id)
    @etop = EmployeeTimeOffPolicy.where(time_off_category: time_off_category)
                                 .find_by(effective_at: new_effective_at)
    @employee = Employee.find(employee_id)
    @manual_amount = manual_amount || balance_at_old_effective_at.try(:manual_amount).to_i
  end

  def starting_date
    @starting_date ||= begin
      if etop.present? && (old_effective_at.nil? || new_effective_at < old_effective_at)
        new_effective_at
      else
        date_in_past
      end
    end
  end

  def ending_date
    @ending_date = begin
      return etop.try(:effective_till) unless old_effective_at.present?
      date_in_future = new_effective_at > old_effective_at ? new_effective_at : old_effective_at
      first_etop_after_date_in_future =
        etops_in_category.where('effective_at > ?', date_in_future).first
      return unless first_etop_after_date_in_future.present?
      first_etop_after_date_in_future.effective_at - 1.day
    end
  end

  def remove_balance_at_old_effective_at!
    return unless balance_at_old_effective_at.present?
    balance_at_old_effective_at.delete
  end

  def recreate_and_recalculate_balances!
    recreate_balances!
    recalculate_balances!
  end

  def etops_in_category
    employee
      .employee_time_off_policies
      .where(time_off_category: time_off_category)
      .order(:effective_at)
  end

  private

  def balance_at_old_effective_at
    return unless old_effective_at.present?
    @balance_at_old_effective_at ||=
      balances_in_category.not_time_off
                          .where('effective_at::date = ?', old_effective_at.to_date)
                          .first
  end

  def recreate_balances!
    create_balance_for_new_or_updated_etop! if etop.present?
    manage_additions!
  end

  def create_balance_for_new_or_updated_etop!
    effective_at = time_off_balance? ? new_effective_at + 5.minutes : new_effective_at
    CreateEmployeeBalance.new(
      time_off_category.id,
      employee.id,
      employee.account.id,
      effective_at: effective_at,
      validity_date: RelatedPolicyPeriod.new(etop).validity_date_for(new_effective_at),
      manual_amount: manual_amount
    ).call
  end

  def time_off_balance?
    balances_in_category.with_time_off.find_by(effective_at: new_effective_at)
  end

  def manage_additions!
    etop_for_manage = etop || first_etop_before
    if old_effective_at.present?
      manage_additions_for_etops_between_dates!
    else
      ManageEmployeeBalanceAdditions.new(etop_for_manage).call
    end
  end

  def manage_additions_for_etops_between_dates!
    end_effective_at = new_effective_at > old_effective_at ? new_effective_at : old_effective_at
    etops = etops_in_category.where(
      'effective_at BETWEEN ? AND ?', starting_date, ending_date || end_effective_at
    )
    etops.each { |etop_between| ManageEmployeeBalanceAdditions.new(etop_between).call }
  end

  def recalculate_balances!
    balance = balance_at_starting_date_or_first_balance
    PrepareEmployeeBalancesToUpdate.new(balance).call
    UpdateBalanceJob.perform_later(balance.id, update_all: true)
  end

  def balance_at_starting_date_or_first_balance
    Employee::Balance.where('effective_at::date = ?', starting_date.to_date).first ||
      Employee::Balance.where('effective_at::date = ?',
        etops_in_category.first.effective_at.to_date).first
  end

  def date_in_past
    @date_in_past = begin
      date =
        if old_effective_at.nil? || old_effective_at > new_effective_at
          new_effective_at
        else
          old_effective_at
        end
      first_etop_before(date).try(:effective_at) || date
    end
  end

  def first_etop_before(date = new_effective_at)
    etops_in_category.where('effective_at < ?', date).last
  end

  def balances_in_category
    employee.employee_balances.where(time_off_category: time_off_category)
  end
end
