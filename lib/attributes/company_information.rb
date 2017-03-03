class CompanyInformation
  include Virtus.model

  attribute :company_name, String
  attribute :additional_address, String
  attribute :street, String
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
