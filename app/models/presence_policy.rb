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
    (Employee.joins(:working_place).where(working_places: { presence_policy_id: id }) +
      Employee.where(presence_policy_id: id).to_a).uniq
  end
end
