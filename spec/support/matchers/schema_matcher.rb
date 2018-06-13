RSpec::Matchers.define :match_schema do |schema_path|
  match do |result|
    JSON::Validator.validate!(schema_path, result, strict: true)
  end
end
