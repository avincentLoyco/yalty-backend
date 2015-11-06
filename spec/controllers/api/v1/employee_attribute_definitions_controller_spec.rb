require 'rails_helper'

RSpec.describe API::V1::EmployeeAttributeDefinitionsController, type: :controller do
  include_context 'shared_context_headers'

  context 'GET #index' do
    before(:each) do
      create_list(:employee_attribute_definition, 3, account: account)
    end

    subject { get :index }

    it { is_expected.to have_http_status(200) }

    context 'response body' do
      before { subject }

      it { expect_json_sizes(5) }
    end

    context 'response body when other account logged in' do
      let(:new_user) { create(:account_user) }
      before(:each) do
        Account.current = new_user.account
      end

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_sizes(2) }
      end
    end
  end

  describe 'GET #show' do
    let(:attribute) { create(:employee_attribute_definition, account: account) }
    let(:id) { attribute.id }
    subject { get :show, id: id }

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json(
            label: attribute.label,
            name: attribute.name,
            system: attribute.system,
            id: attribute.id
          )
        }
      end
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { '12' }

        it { is_expected.to have_http_status(404) }
      end

      context 'with id that belongs to other user' do
        let(:attribute) { create(:employee_attribute_definition) }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'POST #create' do
    let(:name) { 'test' }
    let(:attribute_type) { 'String' }
    let(:params) do
      {
        name: name,
        label: 'test',
        attribute_type: attribute_type,
        system: 'true'
      }
    end

    subject { post :create, params }

    context 'with valid data' do
      it { expect { subject }.to change { Employee::AttributeDefinition.count }.by(1) }
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:name, :system, :type, :id, :attribute_type) }
      end
    end

    context 'with invalid data' do
      context 'with data that do not pass validation' do
        let(:attribute_type) { 'testtype' }

        it { expect { subject }.to_not change { Employee::AttributeDefinition.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with missing data' do
        let(:missing_params_json) { params.tap { |param| param.delete(:attribute_type) } }
        subject { post :create, missing_params_json }

        it { expect { subject }.to_not change { Employee::AttributeDefinition.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'PUT #update' do
    let(:attribute) { create(:employee_attribute_definition, account: account) }
    let(:name) { 'test' }
    let(:id) { attribute.id }
    let(:attribute_type) { 'String' }
    let(:params) do
      {
        id: id,
        name: name,
        label: 'test',
        attribute_type: attribute_type,
        system: 'true'
      }
    end

    subject { put :update, params }

    context 'with valid data' do
      it { expect { subject }.to change { attribute.reload.name } }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { '12' }

        it { expect { subject }.to_not change { attribute.reload.name } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with data that do not pass validation' do
        let(:attribute_type) { 'testtype' }

        it { expect { subject }.to_not change { attribute.reload.name } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with missing params' do
        let(:missing_params_json) { params.tap { |param| param.delete(:attribute_type) } }
        subject { put :update, missing_params_json }

        it { expect { subject }.to_not change { attribute.reload.name } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:attribute) { create(:employee_attribute_definition, account: account) }
    let(:id) { attribute.id }

    subject { delete :destroy, id: id }

    context 'with valid data' do
      it { expect { subject }.to change { Employee::AttributeDefinition.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { '1' }

        it { expect { subject }.to_not change { Employee::AttributeDefinition.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with system resource id' do
        before { attribute.update(system: true) }

        it { expect { subject }.to_not change { Employee::AttributeDefinition.count } }
        it { is_expected.to have_http_status(423) }
      end

      context 'without id' do
        it { expect(delete: "/api/v1/employee_attribute_definitions").not_to be_routable }
      end
    end
  end
end
