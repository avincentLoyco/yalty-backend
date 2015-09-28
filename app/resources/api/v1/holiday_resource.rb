module API
  module V1
    class HolidayResource < JSONAPI::Resource
      model_name 'Holiday'
      attributes :name, :date, :holiday_policy_id
      has_one :holiday_policy, class_name: 'HolidayPolicy'
    end
  end
end
