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

  scope :not_reset, -> { where(reset: false) }
  scope :active, -> { where(active: true) }
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
      .order("employee_presence_policies.effective_at DESC")
  end)

  def self.active_for_employee(employee_id, date)
    actives_for_employee(employee_id, date).first
  end

  def standard_day_duration
    @standard_day_duration ||= begin
      pd = presence_days.with_minutes_not_empty
      return unless pd.any?
      pd.map(&:minutes).sum.to_f / pd.count
    end
  end

  def policy_length
    @policy_length ||= presence_days.maximum(:order).to_i
  end

  def default_full_time?
    account.default_full_time_presence_policy_id == id
  end
end
