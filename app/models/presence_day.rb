class PresenceDay < ActiveRecord::Base
  belongs_to :presence_policy
  has_many :time_entries

  validates :order, presence: true, uniqueness: { scope: :presence_policy_id }
  validates :minutes, numericality: { less_than_or_equal_to: 1440, allow_nil: true }
  validates :presence_policy_id, presence: true

  scope :related, -> (policy_id, order) { find_by(presence_policy_id: policy_id, order: order + 1) }
end
