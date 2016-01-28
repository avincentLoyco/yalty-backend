class WorkingPlaceTimeOffPolicy < ActiveRecord::Base
  belongs_to :working_place
  belongs_to :time_off_policy

  validates :working_place_id, :time_off_policy_id, presence: true
  validates :time_off_policy_id, uniqueness: { scope: :working_place_id }
end
