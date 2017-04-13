module Payments
  class CompanyInformation < ::BasicAttribute
    attribute :company_name, String
    attribute :address_1, String
    attribute :address_2, String
    attribute :city, String
    attribute :postalcode, String
    attribute :country, String
    attribute :region, String
  end
end
