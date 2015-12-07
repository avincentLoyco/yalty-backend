module Attribute
  class String < Attribute::Base
    attribute :string, String

    validates :string, presence: true, allow_nil: false
  end
end
