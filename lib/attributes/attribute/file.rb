module Attribute
  class File < Attribute::Base
    attribute :size, BigDecimal
    attribute :id, String
    attribute :file_sha, String
    attribute :file_type, String
  end
end
