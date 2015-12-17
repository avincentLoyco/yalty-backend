class PresenceDay < ActiveRecord::Base
  belongs_to :presence_policy
  has_many :time_entries

  validates :order, presence: true, uniqueness: { scope: :presence_policy_id }
  validates :presence_policy_id, presence: true
end
