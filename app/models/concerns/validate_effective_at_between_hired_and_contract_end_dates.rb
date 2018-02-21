require "active_support/concern"

module ValidateEffectiveAtBetweenHiredAndContractEndDates
  extend ActiveSupport::Concern

  included do
    validate :effective_at_between_hired_date_and_contract_end, if: [:employee, :effective_at]
    validate :reset_join_table_effective_at_after_contract_end, if: [:employee, :effective_at]
  end

  private

  def reset_join_table_effective_at_after_contract_end
    return if !related_resource.reset? ||
        employee.contract_end_for(effective_at - 1.day) == effective_at - 1.day
    errors.add(:effective_at, "must be set up day after employee contract end date")
  end

  def effective_at_between_hired_date_and_contract_end
    return if related_resource.reset? || employee.contract_periods_include?(effective_at)
    errors.add(:effective_at, "can't be set outside of employee contract period")
  end
end
