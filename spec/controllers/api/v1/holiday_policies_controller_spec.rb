require 'rails_helper'

RSpec.describe API::V1::HolidayPoliciesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'holiday_policy'
  include_examples 'example_crud_resources',
    resource_name: 'holiday_policy'
  include_examples 'example_relationships_working_places',
    resource_name: 'holiday_policy'
  include_context 'shared_context_headers'

  let(:working_place) { create(:working_place, account: account) }
  let(:working_place_id) { working_place.id }

  let(:working_places) {
    [
      {
        id: working_place_id,
        type: "working_places"
      }
    ]
  }

  describe 'POST #create' do
    let(:name) { 'test name' }
    let(:country) { 'pl' }
    let(:region) { '' }
    let(:params) do
      {
        name: name,
        country: country,
        region: region,
        working_places: working_places
      }
    end

    subject { post :create, params }

    context 'with valid data' do
      it { expect { subject }.to change { HolidayPolicy.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(
          [:name, :country, :region, :id, :working_places , :type]
        )}
      end

      context 'records assign' do
        context 'with present ids' do
          it { expect { subject }.to change { working_place.reload.holiday_policy_id } }
        end

        context 'with empty arrays' do
          let(:working_places) { [] }

          it { is_expected.to have_http_status(201) }
        end
      end
    end

    context 'with invalid data' do
      context 'with data that do not pass validation' do
        let!(:country) { 'aa' }

        it { expect { subject }.to_not change { HolidayPolicy.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with attributes missing' do
        let(:missing_params) { params.tap { |param| param.delete(:name) } }
        subject { post :create, missing_params }

        it { expect { subject }.to_not change { HolidayPolicy.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with invalid working place id' do
        let(:working_place_id) { '12' }

        it { expect { subject }.to_not change { HolidayPolicy.count } }
        it { expect { subject }.to_not change { working_place.reload.holiday_policy_id } }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'PUT #update' do
    let(:holiday_policy) { create(:holiday_policy, account: account) }
    let(:id) { holiday_policy.id }
    let(:name) { 'test name' }
    let(:country) { 'pl' }
    let(:region) { '' }
    let(:params) do
      {
        id: id,
        name: name,
        country: country,
        region: region,
        working_places: working_places
      }
    end

    subject { put :update, params }

    shared_examples 'Invalid Data' do
      it { expect { subject }.to_not change { holiday_policy.reload.name } }
      it { expect { subject }.to_not change { holiday_policy.reload.working_places.count } }
    end

    context 'with valid data' do
      it { expect { subject }.to change { holiday_policy.reload.name } }
      it { expect { subject }.to change { holiday_policy.reload.working_places.count }.by(1) }

      it { is_expected.to have_http_status(204) }

      context 'records unassign' do

        context 'with empty working place array' do
          before { holiday_policy.working_places.push(working_place) }
          let!(:working_places) { [] }

          it { expect { subject }.to change { holiday_policy.reload.working_places.count }.by(-1) }
        end
      end
    end

    context 'with invalid data' do
      context 'with data that do not pass validation' do
        let(:name) { '' }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }
      end

      context 'with invalid holiday policy id' do
        let(:id) { '1' }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(404) }
      end

      context 'with missing data' do
        let(:missing_params_json) { params.tap { |param| param.delete(:name) } }
        subject { put :update, missing_params_json }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }
      end

      context 'with invalid related records ids' do
        context 'with invalid working place id' do
          let(:working_place_id) { '1' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end
      end
    end
  end
end
