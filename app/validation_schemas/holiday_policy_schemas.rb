module HolidayPolicySchemas
  include BaseSchemas

  def patch_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      optional(:name).filled(:str?)
      optional(:region).maybe(:str?)
      optional(:country).filled(:str?)
      optional(:working_places).maybe(:array?)
    end
  end

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      optional(:region).maybe(:str?)
      optional(:country).filled(:str?)
      optional(:working_places).maybe(:array?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:name).filled(:str?)
      optional(:region).maybe(:str?)
      optional(:country).filled(:str?)
      optional(:working_places).maybe(:array?)
    end
  end
end
