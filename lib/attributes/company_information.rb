class CompanyInformation
  include Virtus.model

  attribute :company_name, String
  attribute :address_1, String
  attribute :address_2, String
  attribute :city, String
  attribute :postalcode, String
  attribute :country, String
  attribute :region, String

  def self.dump(data)
    data.to_hash
  end

  def self.load(data)
    new(data)
  end
end
