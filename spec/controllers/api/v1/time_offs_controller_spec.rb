require 'rails_helper'

RSpec.describe API::V1::TimeOffsController, type: :controller do
  include_context 'shared_context_headers'

  let(:time_off_category) { create(:time_off_category, account: account) }
  let(:employee) { create(:employee, account: account) }
  let!(:time_off) do
    create(:time_off, time_off_category_id: time_off_category.id, employee: employee)
  end

  describe 'GET #show' do
    subject { get :show, id: id }

    context 'with valid id' do
      let(:id) { time_off.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys([:id, :type, :start_time, :end_time, :employee, :time_off_category]) }
      end
    end

    context 'with invalid id' do
      context 'time off with given id does not exist' do
        let(:id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'time off belongs to other account' do
        before { Account.current = create(:account) }
        let(:id) { time_off.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'GET #index' do
    let(:params) {{ time_off_category_id: time_off_category.id }}
    let!(:time_offs) { create_list(:time_off, 3, time_off_category: time_off_category) }
    subject { get :index, params }

    context 'without employee id param' do
      it 'should return time off category time offs' do
        subject

        time_off_category.time_offs.each do |time_off|
          expect(response.body).to include time_off[:id]
        end
      end

      it { is_expected.to have_http_status(200) }
    end

    context 'with employee id param' do
      before { params.merge!(employee_id: employee.id) }

      it 'should return employee time offs' do
        subject

        expect(response.body).to include time_off.id
      end

      it 'should not return not employee time offs' do
        subject

        time_offs.each do |time_off|
          expect(response.body).to_not include time_off[:id]
        end
      end

      it { is_expected.to have_http_status(200) }
    end

    it 'should not be visible in context of other account' do
      Account.current = create(:account)
      subject

      time_off_category.time_offs.each do |time_off|
        expect(response.body).to_not include time_off[:id]
      end
    end
  end

  describe 'POST #create' do
    let(:start_time) { Time.now }
    let(:end_time) { start_time + 1.week }
    let(:employee_id) { employee.id }
    let(:time_off_category_id) { time_off_category.id }
    let(:params) do
      {
        type: 'time_off',
        start_time: start_time,
        end_time: end_time,
        employee: {
          type: 'employee',
          id: employee_id
        },
        time_off_category: {
          type: 'time_off_category',
          id: time_off_category_id
        }
      }
    end
    subject { post :create, params }

    shared_examples 'Invalid Data' do
      it { expect { subject }.to_not change { TimeOff.count } }
      it { expect { subject }.to_not change { employee.reload.time_offs.count } }
      it { expect { subject }.to_not change { time_off_category.reload.time_offs } }
    end

    context 'with valid params' do
      it { expect { subject }.to change { TimeOff.count }.by(1) }
      it { expect { subject }.to change { time_off_category.reload.time_offs.count }.by(1) }
      it { expect { subject }.to change { employee.reload.time_offs.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response body' do
        before { subject }

        it { expect_json_keys([:id, :type, :employee, :time_off_category, :start_time, :end_time]) }
      end
    end

    context 'with invalid params' do
      context 'when params are missing' do
        before { params.delete(:start_time) }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }
      end

      context 'with params that do not pass validation' do
        let(:end_time) { start_time - 1.week }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }
      end

      context 'with invalid id' do
        context 'with invalid employee id' do
          let(:employee_id) { 'abc' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end

        context 'with employee does not belong to account' do
          before { Account.current = create(:account) }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end

        context 'with invalid category id' do
          let(:time_off_category_id) { 'abc' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end

        context 'with category does not belong to account' do
          before { Account.current = create(:account) }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }
        end
      end
    end
  end

  describe 'PUT #update' do
    let(:id) { time_off.id }
    let(:start_time) { Time.now }
    let(:end_time) { start_time + 1.week }
    let(:params) do
      {
        id: id,
        type: 'time_off',
        start_time: start_time,
        end_time: end_time,
      }
    end

    subject { put :update, params }

    context 'with valid params' do
      it { expect { subject }.to change { time_off.reload.start_time } }
      it { expect { subject }.to change { time_off.reload.end_time } }

      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'params are missing' do
        before { params.delete(:start_time) }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }

        it { is_expected.to have_http_status(422) }
      end

      context 'params do not pass validation' do
        let(:end_time) { start_time - 1.week }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }

        it { is_expected.to have_http_status(422) }
      end

      context 'invalid id given' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { time_off.reload.start_time } }
        it { expect { subject }.to_not change { time_off.reload.end_time } }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, id: id }
    let(:id) { time_off.id }

    context 'with valid data' do
      let(:id) { time_off.id }

      it { expect { subject }.to change { TimeOff.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { TimeOff.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with not account id' do
        before { Account.current = create(:account) }

        it { expect { subject }.to_not change { TimeOff.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
