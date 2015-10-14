require 'rails_helper'

RSpec.describe API::V1::EmployeesController, type: :controller do
  include_context 'shared_context_headers'

  let(:attribute_definition) {
    create(
      :employee_attribute_definition,
      attribute_type: 'String',
      account: account
    )
  }

  context 'GET #show' do
    context 'valid data' do
      let(:employee) { create(:employee, :with_attributes, account: account) }
      subject { get :show, id: employee.id }

      it 'should have type and id' do
        subject

        expect_json_types(id: :string, type: :string, employee_attributes: :array)
      end

      it 'should have employee_attributes' do
        subject

        expect_json_keys('employee_attributes.*', [:id, :type, :value, :attribute_name])
      end

      it 'should respond with success' do
        subject

        expect(response).to have_http_status(200)
      end
    end

    context 'invalid data' do
      it 'should respond with 404 when invalid id given' do
        get :show, id: '12345678-1234-1234-1234-123456789012'

        expect(response).to have_http_status(404)
      end

      it 'should repsons with 404 when not user employee id given' do
        not_account_employee = create(:employee)
        get :show, id: not_account_employee.id

        expect(response).to have_http_status(404)
      end
    end
  end

  context 'GET #index' do
    before(:each) do
      create_list(:employee, 3, :with_attributes, account: account)
    end

    it 'should respond with success' do
      get :index

      expect(response).to have_http_status(:success)
      expect_json_sizes(3)
    end

    it 'should have id, type and employee attributes' do
      get :index

      expect_json_types('*', id: :string, type: :string, employee_attributes: :array)
    end

    it 'should not be visible in context of other account' do
      user = create(:account_user)
      Account.current = user.account

      get :index

      expect(response).to have_http_status(:success)
      expect_json_sizes(0)
    end
  end
end
