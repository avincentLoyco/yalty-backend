require 'rails_helper'

RSpec.describe API::V1::TimeOffCategoriesController, type: :controller do
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
end
