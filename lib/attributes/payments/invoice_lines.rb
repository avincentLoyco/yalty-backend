module Payments
  class InvoiceLines < Basic
    attribute :data, Array[InvoiceLine]
  end
end
