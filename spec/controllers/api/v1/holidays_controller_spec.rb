require 'rails_helper'

RSpec.describe API::V1::HolidaysController, type: :controller do
  include_context 'shared_context_headers'

  let(:account){ create(:account)}
  let(:holiday_policy){ create(:holiday_policy, account: account) }
  let!(:holiday){ create(:holiday, holiday_policy: holiday_policy) }

  describe "GET #show" do
    subject { get :show, id: id }

    context 'with valid data' do
      let(:id) { holiday.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_types(id: :string, type: :string, date: :string, name: :string) }
      end
    end

    context 'invalid data' do
      context 'with invalid id' do
        let(:id) { '12' }

        it { is_expected.to have_http_status(404) }
      end

      context 'with holiday that not belong to user' do
        let(:holiday) { create(:holiday) }
        let(:id) { holiday.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe "GET #index" do
    let(:holiday_policy_id) { holiday_policy.id }
    subject { get :index, holiday_policy_id: holiday_policy_id }

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'custom holidays response' do
        before { subject }

        it { expect_json_types('0', id: :string, type: :string, date: :string, name: :string) }
        it { expect_json_sizes(1) }
      end

      context 'default holidays response' do
        context 'for country Poland' do
          let!(:country_holiday_policy) { create(:holiday_policy, :with_country, account: account) }
          let(:holiday_policy_id) { country_holiday_policy.id }

          it { is_expected.to have_http_status(200) }

          context 'response' do
            before { subject }

            it { expect_json_sizes(14) }
          end
        end

        context 'for country Switzerland and land Zurich' do
          let(:region_holiday_policy) { create(:holiday_policy, :with_region, account: account) }
          let(:holiday_policy_id) { region_holiday_policy.id }

          it { is_expected.to have_http_status(200) }

          context 'response' do
            before { subject }

            it { expect_json_sizes(10) }
          end
        end

        context 'for country Poland and custom users holidays' do
          let(:holiday_policy) { create(:holiday_policy, :with_country, account: account) }
          let(:holiday_policy_id) { holiday_policy.id }

          it { is_expected.to have_http_status(200) }

          context 'response' do
            before { subject }

            it { expect_json_sizes(15) }
          end
        end
      end
    end

    context 'with invalid data' do
      context 'invalid holiday policy id' do
        let(:holiday_policy_id) { '12' }

        it { is_expected.to have_http_status(404) }
      end

      context 'not user holiday policy' do
        let(:holiday_policy) { create(:holiday_policy) }
        let(:holiday_policy_id) { holiday_policy.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'POST #create' do
    let(:name) { 'test' }
    let(:date) { Date.new }
    let(:holiday_policy_id) { holiday_policy.id }
    let(:valid_params_json) do
      {
        name: name,
        type: 'holiday',
        date: date,
        holiday_policy: {
          id: holiday_policy_id
        }
      }
    end
    subject { post :create, valid_params_json }

    context 'with valid data' do
      it { expect { subject }.to change { Holiday.count }.by(1) }
      it { expect { subject }.to change { holiday_policy.reload.holidays.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json(name: name, type: 'holiday', date: date.strftime('%d/%m')) }
      end
    end

    context 'with invalid data' do
      context 'with invalid holiday policy id' do
        let(:holiday_policy_id) { '1' }

        it { expect { subject }.to_not change { Holiday.count } }
        it { expect { subject }.to_not change { holiday_policy.reload.holidays.count } }

        it { is_expected.to have_http_status(404) }

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'id', messages: 'Record Not Found', status: 'invalid', type: 'nil_class' }
            ]
          )}
        end
      end

      context 'with holiday policy that not belong to account' do
        let(:not_user_holiday_policy) { create(:holiday_policy) }
        let(:holiday_policy_id) { not_user_holiday_policy.id }

        it { expect { subject }.to_not change { Holiday.count } }
        it { expect { subject }.to_not change { holiday_policy.reload.holidays.count } }

        it { is_expected.to have_http_status(404) }

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'id', messages: 'Record Not Found', status: 'invalid', type: 'nil_class' }
            ]
          )}
        end
      end

      context 'with data that do not pass validation' do
        let(:name) { '' }

        it { expect { subject }.to_not change { Holiday.count } }
        it { expect { subject }.to_not change { holiday_policy.reload.holidays.count } }

        it { is_expected.to have_http_status(422) }

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'name', messages: ["can't be blank"], status: 'invalid', type: 'holiday' }
            ]
          )}
        end
      end

      context 'with missing data' do
        let(:invalid_params_json) { valid_params_json.tap { |attr| attr.delete(:date) } }
        subject { post :create, invalid_params_json }

        it { expect { subject }.to_not change { Holiday.count } }
        it { expect { subject }.to_not change { holiday_policy.reload.holidays.count } }

        it { is_expected.to have_http_status(422) }

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'date', messages: 'missing', status: 'invalid', type: 'gate_result' }
            ]
          )}
        end
      end
    end
  end


  describe "PUT #update" do
    let(:name) { 'test' }
    let(:date) { Date.new }
    let(:id) { holiday.id }
    let(:valid_params_json) do
      {
        id: id,
        name: name,
        type: 'holiday',
        date: date
      }
    end

    subject { put :update, valid_params_json }

    shared_examples 'Invalid Data' do
      it { expect { subject }.to_not change { holiday.reload.name } }
      it { expect { subject }.to_not change { holiday.reload.date } }
      it { expect { subject }.to_not change { holiday.reload.holiday_policy } }
    end

    context 'with valid params' do
      it { expect { subject }.to change { holiday.reload.name } }
      it { expect { subject }.to change { holiday.reload.date } }
      it { expect { subject }.to_not change { holiday.reload.holiday_policy } }

      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'with invalid id' do
        let(:id) { '12' }

        it_behaves_like 'Invalid Data'

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'id', messages: 'Record Not Found', status: 'invalid', type: 'nil_class' }
            ]
          )}
        end
      end

      context 'with id that belongs to other account holiday' do
        let(:not_user_holiday) { create(:holiday) }
        let(:id) { not_user_holiday.id }

        it_behaves_like 'Invalid Data'

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'id', messages: 'Record Not Found', status: 'invalid', type: 'nil_class' }
            ]
          )}
        end
      end

      context 'with data that do not pass validation' do
        let(:name) { '' }

        it_behaves_like 'Invalid Data'

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'name', messages: ["can't be blank"], status: 'invalid', type: 'holiday' }
            ]
          )}
        end
      end

      context 'with missing data' do
        let(:invalid_params_json) { valid_params_json.tap { |attr| attr.delete(:date) } }
        subject { put :update, invalid_params_json }

        it_behaves_like 'Invalid Data'

        context 'response body' do
          before { subject }

          it { expect_json(
            errors: [
              { field: 'date', messages: 'missing', status: 'invalid', type: 'gate_result' }
            ]
          )}
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:id) { holiday.id }
    subject { delete :destroy, id: id }

    context 'with valid data' do
      it { expect { subject }.to change { Holiday.count }.by(-1) }

      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { '12' }

        it { expect { subject }.to_not change { Holiday.count } }

        it { is_expected.to have_http_status(404) }
      end

      context 'with id that not belongs to other account holidays' do
        let!(:not_user_holiday) { create(:holiday) }
        let(:id) { not_user_holiday.id }

        it { expect { subject }.to_not change { Holiday.count } }

        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
