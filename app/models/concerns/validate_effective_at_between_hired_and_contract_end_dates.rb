require 'active_support/concern'

module ValidateEffectiveAtBetweenHiredAndContractEndDates
  extend ActiveSupport::Concern

  included do
    validate :effective_at_cannot_be_before_hired_date, if: [:employee, :effective_at]
    validate :effective_at_between_hired_date_and_contract_end, if: [:employee, :effective_at]
  end

  private

  def effective_at_cannot_be_before_hired_date
    return unless employee.hired_date.present? && effective_at.to_date < employee.hired_date
    errors.add(:effective_at, 'can\'t be set before employee hired date')
  end

  def effective_at_between_hired_date_and_contract_end
    return unless employee.contract_end_for(effective_at) != (effective_at - 1.day) &&
                  employee.contract_end_for(effective_at).present? &&
                  employee.contract_end_for(effective_at) > employee.hired_date_for(effective_at)
    errors.add(:effective_at, 'can\'t be set after employee contract end date')
  end
end
