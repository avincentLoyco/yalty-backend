class PresenceDay < ActiveRecord::Base
  belongs_to :presence_policy

  validates :order, presence: true, uniqueness: true
  validates :presence_policy_id, presence: true
end
