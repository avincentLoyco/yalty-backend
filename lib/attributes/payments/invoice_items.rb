module Payments
  class InvoiceItems < Basic
    attribute :data, Array[InvoiceItem]
  end
end
