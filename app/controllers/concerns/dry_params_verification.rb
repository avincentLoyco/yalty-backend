module DryParamsVerification
  def verified_dry_params(schema)
    result = schema.call(params)
    return yield(result.output) if result.messages.empty?
    render json: ::Api::V1::ErrorsRepresenter.new(result, result.messages).complete, status: 422
  end
end
