module Api::V1::Payments
  class CardsRepresenter < Api::V1::BaseRepresenter
    def complete
      {
        id: resource.id,
        last4: resource.last4,
        brand: resource.brand,
        exp_month: resource.exp_month,
        exp_year: resource.exp_year,
        default: resource.default,
        name: resource.name
      }
    end
  end
end
