module Attribute
  class Date < Attribute::Base
    attribute :date, Date

    def self.ruby_type
      'Date'
    end
  end
end
