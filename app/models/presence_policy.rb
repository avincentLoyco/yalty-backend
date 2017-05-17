class PresencePolicy < ActiveRecord::Base
  include ActsAsIntercomTrigger

  has_many :employees
  has_many :presence_days, dependent: :destroy
  has_many :time_entries, through: :presence_days
  has_many :employee_presence_policies
  has_many :employees, through: :employee_presence_policies

  belongs_to :account

  validates :account_id, :name, presence: true

  before_create :set_standard_day_duration,
    if: -> { !standard_day_duration.present? && presence_days.any? }

  scope :not_reset, -> { where(reset: false) }
  scope :for_account, ->(account_id) { not_reset.where(account_id: account_id) }

  scope(:active_for_employee, lambda do |employee_id, date|
    joins(:employee_presence_policies)
      .where("employee_presence_policies.employee_id= ? AND
              employee_presence_policies.effective_at <= ?", employee_id, date)
      .order('employee_presence_policies.effective_at desc')
      .first
  end)

  def last_day_order
    presence_days.pluck(:order).max
  end

  def set_standard_day_duration
    self.standard_day_duration = presence_days.map(&:minutes).compact.max
  end
end
