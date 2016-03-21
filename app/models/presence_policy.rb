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
    working_place_ids = working_places.joins(:employees)
                                      .where(employees: { presence_policy_id: nil })
                                      .map(&:employee_ids).flatten
    Employee.where('presence_policy_id = ? OR id IN (?)', id, working_place_ids)
  end
end
