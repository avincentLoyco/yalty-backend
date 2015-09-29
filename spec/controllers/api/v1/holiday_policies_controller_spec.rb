require 'rails_helper'

RSpec.describe API::V1::HolidayPoliciesController, type: :controller do
  include_examples 'example_crud_resources',
    resource_name: 'holiday_policy'
  include_examples 'example_relationships_employees',
    resource_name: 'holiday_policy'
end
