class Notification < ActiveRecord::Base
  belongs_to :user, required: true, class_name: "Account::User", inverse_of: :notifications
  belongs_to :resource, polymorphic: true

  scope :unread, -> { where(seen: false).order(created_at: :desc) }
end
