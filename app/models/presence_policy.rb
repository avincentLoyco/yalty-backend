class PresencePolicy < ActiveRecord::Base
  has_many :employees
  has_many :presence_days
  has_many :time_entries, through: :presence_days
  has_many :employee_presence_policies
  has_many :employees, through: :employee_presence_policies

  belongs_to :account

  validates :account_id, :name, presence: true

  def last_day_order
    presence_days.pluck(:order).max
  end

  def affected_employees
    Employee.joins(:employee_presence_policies)
            .where(employee_presence_policies: { presence_policy_id: id })
  end
end
