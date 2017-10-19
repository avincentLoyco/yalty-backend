class PresencePolicy < ActiveRecord::Base
  include ActsAsIntercomTrigger

  has_many :employees
  has_many :presence_days, dependent: :destroy
  has_many :time_entries, through: :presence_days
  has_many :employee_presence_policies
  has_many :employees, through: :employee_presence_policies

  belongs_to :account

  validates :account_id, :name, presence: true
  validates :occupation_rate,
    numericality: { less_than_or_equal_to: 1, greater_than_or_equal_to: 0 }

  before_create :set_standard_day_duration,
    if: -> { !standard_day_duration.present? && presence_days.any? }

  scope :not_reset, -> { where(reset: false) }
  scope :for_account, ->(account_id) { not_reset.where(account_id: account_id) }

  scope(:actives_for_employee, lambda do |employee_id, date|
    joins(:employee_presence_policies)
      .where("
        employee_presence_policies.employee_id = ? AND
        employee_presence_policies.effective_at BETWEEN (
          SELECT employee_events.effective_at FROM employee_events
	      WHERE employee_events.employee_id = ?
          AND employee_events.effective_at <= ?::date
	      AND employee_events.event_type = 'hired'
	      ORDER BY employee_events.effective_at DESC LIMIT 1
        ) AND ?::date", employee_id, employee_id, date.to_date, date.to_date)
      .order('employee_presence_policies.effective_at DESC')
  end)

  def self.active_for_employee(employee_id, date)
    actives_for_employee(employee_id, date).first
  end

  def set_standard_day_duration
    self.standard_day_duration = presence_days.map(&:minutes).compact.max
  end
end
