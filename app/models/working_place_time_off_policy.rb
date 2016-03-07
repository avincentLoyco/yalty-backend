class WorkingPlaceTimeOffPolicy < ActiveRecord::Base
  belongs_to :working_place
  belongs_to :time_off_policy
  has_many :employees, through: :working_place

  validates :working_place_id, :time_off_policy_id, presence: true
  validates :time_off_policy_id, uniqueness: { scope: :working_place_id }

  scope :affected_employees, lambda { |policy_id|
    where(time_off_policy_id: policy_id).joins(:working_place)
      .joins(:employees).pluck(:'employees.id')
  }
end
