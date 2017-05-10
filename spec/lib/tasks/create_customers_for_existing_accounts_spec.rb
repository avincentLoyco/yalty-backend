require 'rails_helper'
require 'rake'

RSpec.describe 'payments:create_customers_for_existing_accounts', type: :rake, jobs: true do
  include_context 'rake'

  before do
    create(:account, customer_id: 'cus_123', subscription_id: 'sub_123')
    create_list(:account, 3, customer_id: nil, subscription_id: nil)
  end

  context 'in case of success' do
    context 'when customer and subscription does not exist' do
      it { expect { subject }.to have_enqueued_job(::Payments::CreateOrUpdateCustomerWithSubscription).exactly(3) }
    end

    context 'when subscription_id is nil' do
      before { Account.where('subscription_id IS NOT NULL').update_all(subscription_id: nil) }

      it { expect { subject }.to have_enqueued_job(::Payments::CreateOrUpdateCustomerWithSubscription).exactly(4) }
    end
  end
end
