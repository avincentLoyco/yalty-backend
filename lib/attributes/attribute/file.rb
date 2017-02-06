module Attribute
  class File < Attribute::Base
    attribute :size, BigDecimal
    attribute :id, String
    attribute :original_sha, String
    attribute :thumbnail_sha, String
    attribute :file_type, String

    def optional_attributes
      %s(thumbnail_sha)
    end
  end
end
