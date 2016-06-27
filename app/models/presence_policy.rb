class PresencePolicy < ActiveRecord::Base
  has_many :employees
  has_many :presence_days
  has_many :time_entries, through: :presence_days
  has_many :employee_presence_policies
  has_many :employees, through: :employee_presence_policies

  belongs_to :account

  validates :account_id, :name, presence: true

  scope :active_for_employee, lambda { |employee_id, date|
    joins(:employee_presence_policies)
      .where("employee_presence_policies.employee_id= ? AND
              employee_presence_policies.effective_at <= ?", employee_id, date)
      .order('employee_presence_policies.effective_at desc')
      .first
  }

  def last_day_order
    presence_days.pluck(:order).max
  end
end
