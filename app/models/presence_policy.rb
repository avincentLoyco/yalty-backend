class PresencePolicy < ActiveRecord::Base
  has_many :employees
  has_many :working_places
  has_many :presence_days
  has_many :time_entries, through: :presence_days
  belongs_to :account

  validates :account_id, :name, presence: true

  def last_day_order
    presence_days.pluck(:order).max
  end

  def affected_employees
    employees = []
    Employee.all.map do |employee|
      employees << employee if employee.active_presence_policy == self
    end
    employees
  end
end
