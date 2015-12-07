module Attribute
  class Date < Attribute::Base
    attribute :date, Date

    validates :date, presence: true
  end
end
