class PresenceDay < ActiveRecord::Base
  belongs_to :presence_policy
  has_many :time_entries, dependent: :destroy

  validates :order, presence: true, uniqueness: { scope: :presence_policy_id }
  validates :presence_policy_id, presence: true

  # TODO check if those two scopes could be replaced by only one
  scope :with_minutes_not_empty, -> { where("minutes IS NOT NULL and minutes <> 0") }
  scope :with_entries, -> { joins(:time_entries).includes(:time_entries) }

  def update_minutes!
    update!(minutes: calculated_day_minutes)
  end

  private

  def calculated_day_minutes
    return 0 unless time_entries.present?
    time_entries.sum(:duration)
  end
end
