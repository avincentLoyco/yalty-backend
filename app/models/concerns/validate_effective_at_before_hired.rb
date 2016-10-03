require 'active_support/concern'

module ValidateEffectiveAtBeforeHired
  extend ActiveSupport::Concern

  included do
    validate :effective_at_cannot_be_before_hired_date, if: [:employee, :effective_at]
  end

  private

  def effective_at_cannot_be_before_hired_date
    return unless employee.hired_date.present? && effective_at.to_date < employee.hired_date
    errors.add(:effective_at, 'can\'t be set before employee hired date')
  end
end
