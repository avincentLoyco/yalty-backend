require 'rails_helper'

RSpec.describe API::V1::TimeOffCategoriesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'time_off_category'
  include_context 'shared_context_headers'

  describe 'GET #index' do
    let!(:time_off_categories) { create_list(:time_off_category, 3, account: account) }
    subject { get :index }

    it { is_expected.to have_http_status(200) }

    it 'should return current account time off categories' do
      subject

      account.time_off_categories.each do |category|
        expect(response.body).to include category[:id]
      end
    end

    it 'should not be visible in context of other account' do
      Account.current = create(:account)
      subject

      account.time_off_categories.each do |category|
        expect(response.body).to_not include category[:id]
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, id: id }
    let(:category) { create(:time_off_category, account: account) }

    context 'with valid id' do
      let(:id) { category.id }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:id, :type, :system, :name) }
        it { expect_json(
          id: category.id,
          type: 'time_off_category',
          system: category.system,
          name: category.name)
        }
      end
    end

    context 'with invalid id' do
      context 'time of with given id does not exist' do
        let(:id) { 'abc' }

        it { is_expected.to have_http_status(404) }
      end

      context 'time of category belongs to other account' do
        before { Account.current = create(:account) }
        let(:id) { category.id }

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'POST #create' do
    let(:name) { 'testname' }
    let(:params) do
      {
        system: false,
        name: name
      }
    end
    subject { post :create, params }

    context 'with valid params' do
      it { expect { subject }.to change { TimeOffCategory.count }.by(1) }

      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }

        it { expect_json_keys(:id, :type, :system, :name) }
      end
    end

    context 'with invalid params' do
      context 'with missing params' do
        before { params.delete(:name) }

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with params that do not pass validation' do
        let(:name) { '' }

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(422) }
      end
    end
  end

  describe 'PUT #update' do
    subject { put :update, params }
    let(:time_off_category) { create(:time_off_category, account: account) }
    let(:name) { 'abc' }
    let(:id) { time_off_category.id }
    let(:params) do
      {
        id: id,
        name: name,
        system: 'false'
      }
    end

    context 'with valid data' do
      it { expect { subject }.to change { time_off_category.reload.name } }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid data' do
      context 'with invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(404) }
      end

      context 'with missing params' do
        before { params.delete(:name) }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with params that do not pass validation' do
        let(:name) { '' }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(422) }
      end

      context 'with not editable resource' do
        let(:system_time_off_category) { create(:time_off_category, :system) }
        let(:id) { system_time_off_category.id }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:time_off_category) { create(:time_off_category, account: account) }
    let(:id) { time_off_category.id }
    subject { delete :destroy, id: id }

    context 'with valid params' do
      it { expect { subject }.to change { TimeOffCategory.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'with invalid params' do
      context 'with invalid id' do
        let(:id) { 'abc' }

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(404) }
      end

      context 'when time off category has time offs assigned' do
        let!(:time_off) { create(:time_off, time_off_category_id: time_off_category.id) }

        it { expect { subject }.to_not change { TimeOffCategory.count } }
        it { is_expected.to have_http_status(423) }
      end

      context 'with not editable resource' do
        let(:system_time_off_category) { create(:time_off_category, :system) }
        let(:id) { system_time_off_category.id }

        it { expect { subject }.to_not change { time_off_category.reload.name  } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
