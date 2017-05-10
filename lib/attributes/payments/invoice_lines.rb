module Payments
  class InvoiceLines < ::SimpleAttribute
    attribute :data, Array[InvoiceLine]
  end
end
