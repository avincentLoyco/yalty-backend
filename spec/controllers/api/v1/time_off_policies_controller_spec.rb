require 'rails_helper'

RSpec.describe API::V1::TimeOffPoliciesController, type: :controller do
  include_context 'shared_context_headers'

  let(:time_off_category) { create(:time_off_category, account: account) }
  let!(:policy) { create(:time_off_policy, time_off_category: time_off_category) }
  let(:working_place) { create(:working_place) }
  let(:employee) { create(:employee, account: account) }


  describe 'GET #index' do
    let!(:time_off_policies) do
      create_list(:time_off_policy, 3, time_off_category: time_off_category)
    end

    context "without params" do
      subject { get :index }

      it { is_expected.to have_http_status(200) }

      it 'should return current account time off policies' do
        subject

        account.time_off_policies.each do |policy|
          expect(response.body).to include policy[:id]
        end
      end

      it 'should not be visible in context of other account' do
        Account.current = create(:account)
        subject

        account.time_off_policies.each do |policy|
            expect(response.body).to_not include policy[:id]
        end
      end
    end

    context "with params" do
      let(:time_off_category_id) { time_off_category.id }
      let(:params) { { time_off_category_id: time_off_category_id } }
      let(:another_time_off_category) { create(:time_off_category, account: account) }
      let(:another_policy) do
        create(:time_off_policy, time_off_category: another_time_off_category)
      end

      subject { get :index, params}

      context 'and when time_off_category_id belongs to other accout' do
        let(:time_off_category_id) { create(:time_off_category).id }

        it { is_expected.to have_http_status(404) }
      end

      it 'should return current account time off policies for the given category' do

        another_policy
        subject

        time_off_category.time_off_policies.each do |policy|
            expect(response.body).to include policy[:id]
        end
        another_time_off_category.time_off_policies.each do |policy|
            expect(response.body).to_not include policy[:id]
        end
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, id: id }

    context 'with valid id' do
      let(:id) { policy.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it '' do
          expect_json_keys(
            [ :id,
              :type,
              :name,
              :start_day,
              :end_day,
              :start_month,
              :end_month,
              :amount,
              :policy_type,
              :years_to_effect,
              :years_passed,
              :time_off_category,
              :employees,
              :working_places
            ]
          )
        end
      end
    end

    context 'with invalid id' do
      context 'time off policy with given id does not exist' do
        let(:id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'time off policy belongs to other account' do
        before { Account.current = create(:account) }
        let(:id) { policy.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'POST #create' do
    let(:working_place_id) { working_place.id }
    let(:employee_id) { employee.id }
    let(:time_off_category_id) { time_off_category.id }
    let(:policy_type) { 'balance' }
    let(:start_day) { 10 }
    let(:params) do
      {
        name: 'Vacations of Adams',
        type: 'time_off_policy',
        start_day: start_day,
        end_day: 7,
        start_month: 8,
        end_month: 7,
        amount: 20,
        policy_type: policy_type,
        years_to_effect: 2,
        time_off_category:{
          id: time_off_category_id,
          type: 'time_off_category'
        },
        employees: [
          {
            id: employee_id,
            type: 'employee'
          }
        ],
        working_places: [
          { id: working_place_id,
            type: 'working_place'
          }
        ]
      }
    end
    subject { post :create, params }

    context 'with valid params' do
      it { expect { subject }.to change { TimeOffPolicy.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it "" do
          expect_json_keys(
            [ :id,
              :type,
              :name,
              :start_day,
              :end_day,
              :start_month,
              :end_month,
              :amount,
              :policy_type,
              :years_to_effect,
              :time_off_category,
              :employees,
              :working_places
            ]
          )
        end
      end

      context 'without not obligatory params' do
        before do
          params.delete(:years_to_effect)
          params.delete(:working_places)
          params.delete(:employees)
          params.delete(:end_day)
          params.delete(:end_month)
        end
        context 'for type balancer' do

          it { expect { subject }.to change { TimeOffPolicy.count }.by(1) }
          it { is_expected.to have_http_status(201) }
        end
        context 'for type counter' do
          let(:policy_type) { 'counter' }
          before do
            params.delete(:amount)
          end

          it { expect { subject }.to change { TimeOffPolicy.count }.by(1) }
          it { is_expected.to have_http_status(201) }
        end
      end

      context 'and when time_off_category_id belongs to other accout' do
        let(:time_off_category_id) { create(:time_off_category).id }

        it { is_expected.to have_http_status(404) }
      end
    end

    context 'with invalid params' do
      context 'with missing obligatory params' do
        before { params.delete(:start_day) }

        it { expect { subject }.to_not change { TimeOffPolicy.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with params that do not pass validation' do
        let(:start_day) { '' }

        it { expect { subject }.to_not change { TimeOffPolicy.count } }
        it { is_expected.to have_http_status(422) }
      end

      context ' and with only ' do
        context 'end_day in params but no end_month' do
          before { params.delete(:end_month) }

          it { expect { subject }.to_not change { TimeOffPolicy.count } }
          it { is_expected.to have_http_status(422) }
        end
        context 'end_month in params but no end_day' do
          before { params.delete(:end_day) }

          it { expect { subject }.to_not change { TimeOffPolicy.count } }
          it { is_expected.to have_http_status(422) }
        end
      end
    end
  end

  describe 'PUT #update' do
    subject { put :update, params }
    let(:new_time_off_category) { create(:time_off_category, account: account) }
    let(:id) { policy.id }
    let(:working_place_id) { working_place.id }
    let(:employee_id) { employee.id }
    let(:time_off_category_id) { new_time_off_category.id }
    let(:start_day) { 10 }
    let(:end_day) { 7 }
    let(:end_month) { 7 }
    let(:params) do
      {
        name: 'Vacations of Adams',
        id: id,
        type: 'time_off_policy',
        start_day: start_day,
        end_day: end_day,
        start_month: 8,
        end_month: end_month,
        amount: 20,
        policy_type: 'balance',
        years_to_effect: 2,
        employees: [
          {
            id: employee_id,
            type: 'employee'
          }
        ],
        working_places: [
          { id: working_place_id,
            type: 'working_place'
          }
        ]
      }
    end

    context 'with valid data' do
      it { expect { subject }.to change { policy.reload.start_day } }
      it { is_expected.to have_http_status(204) }

      context 'without not obligatory params' do
        before do
          params.delete(:name)
          params.delete(:amount)
          params.delete(:working_places)
          params.delete(:employees)
          params.delete(:years_to_effect)
        end
        it { expect { subject }.not_to change { policy.reload.time_off_category_id } }
        it { expect { subject }.to change { policy.reload.start_day } }
        it { is_expected.to have_http_status(204) }
      end
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { policy.reload.start_day  } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with missing obligatory params' do
        before { params.delete(:start_day) }

        it { expect { subject }.to_not change { policy.reload.start_day  } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with params that do not pass validation' do
        let(:start_day) { '' }

        it { expect { subject }.to_not change { policy.reload.start_day  } }
        it { is_expected.to have_http_status(422) }
      end

      context 'when params have' do
        context 'end_day is nil' do
          let(:end_day) { nil }

          it { expect { subject }.to_not change { TimeOffPolicy.count } }
          it { is_expected.to have_http_status(422) }
        end
        context 'end_month but no end_day' do
          let(:end_month) { nil }

          it { expect { subject }.to_not change { TimeOffPolicy.count } }
          it { is_expected.to have_http_status(422) }
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:id) { policy.id }
    subject { delete :destroy, id: id }

    context 'with valid params' do
      it { expect { subject }.to change { TimeOffPolicy.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'with invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { TimeOffPolicy.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when time off policy has an employee balance' do
        let!(:employee_balance) do
          create(:employee_balance,
            time_off_category: time_off_category,
            time_off_policy: policy
          )
        end

        it { expect { subject }.to_not change { TimeOffPolicy.count } }
        it { is_expected.to have_http_status(423) }
      end
    end
  end
end
