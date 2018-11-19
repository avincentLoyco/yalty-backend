module PresencePolicySchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      required(:occupation_rate).filled(:float?)
      required(:presence_days).filled.each do
        schema do
          required(:order).filled(:int?)
          required(:time_entries).each do
            schema do
              required(:start_time).filled(:str?)
              required(:end_time).filled(:str?)
            end
          end
        end
      end
      optional(:default_full_time).filled(:bool?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:name).filled(:str?)
      optional(:occupation_rate).filled(:float?)
      optional(:default_full_time).filled(:bool?)
    end
  end
end
