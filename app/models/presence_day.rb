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

  def next_day
    next_day_order = order == presence_policy.last_day_order ? 1 : order + 1
    presence_policy.presence_days.where(order: next_day_order).first
  end

  def previous_day
    previous_day_order = order == 1 ? presence_policy.last_day_order : order - 1
    presence_policy.presence_days.find_by(order: previous_day_order)
  end

  def last_day_entry
    time_entries.find_by(start_time: time_entries.pluck(:start_time).max)
  end

  def first_day_entry
    time_entries.find_by(start_time: time_entries.pluck(:start_time).min)
  end

  private

  def calculated_day_minutes
    return 0 unless time_entries.present?
    time_entries.sum(:duration)
  end
end
