module GateParams
  def verified_params(rules)
    result = rules.verify(params)
    if result.valid?
      yield(result.attributes)
    else
      render json:
        ::Api::V1::ErrorsRepresenter.new(result).complete, status: 422
    end
  end
end
