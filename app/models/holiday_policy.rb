class HolidayPolicy < ActiveRecord::Base
  validates :name, presence: true
end
