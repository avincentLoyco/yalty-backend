module Attribute
  class Boolean < Attribute::Base
    attribute :boolean, Boolean

    def self.ruby_type
      'Boolean'
    end
  end
end
