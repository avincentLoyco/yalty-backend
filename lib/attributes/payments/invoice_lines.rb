module Payments
  class InvoiceLines < ::BasicAttribute
    attribute :data, Array[InvoiceLine]
  end
end
