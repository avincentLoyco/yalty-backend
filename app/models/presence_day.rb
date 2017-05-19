class PresenceDay < ActiveRecord::Base
  belongs_to :presence_policy
  has_many :time_entries, dependent: :destroy

  validates :order, presence: true, uniqueness: { scope: :presence_policy_id }
  validates :presence_policy_id, presence: true

  scope :with_entries, lambda { |policy_id|
    joins(:time_entries)
      .where('time_entries.id IS NOT NULL AND presence_policy_id = ?', policy_id)
  }

  def update_minutes!
    update!(minutes: calculated_day_minutes)
  end

  private

  def calculated_day_minutes
    return 0 unless time_entries.present?
    time_entries.sum(:duration)
  end
end
