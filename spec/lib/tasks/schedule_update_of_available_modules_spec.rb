require 'rails_helper'
require 'rake'

RSpec.describe 'payments:schedule_update_of_available_modules', type: :rake do
  include_context 'rake'

  let!(:acounts_with_stripe) { create_list(:account, 4, :with_stripe_fields) }
  let!(:acounts_without_stripe) { create_list(:account, 4) }

  before do
    allow(::Payments::UpdateAvailableModules).to receive(:perform_now)
    allow(::Payments::CreateOrUpdateCustomerWithSubscription).to receive(:perform_now)
  end

  it 'schedules a job for every account with customer and subscription' do
    expect(::Payments::UpdateAvailableModules).to receive(:perform_now).exactly(4).times
    subject
  end

  it 'schedules a CreateOrUpdateCustomerWithSubscription job for every account without stripe' do
    expect(::Payments::CreateOrUpdateCustomerWithSubscription).to receive(:perform_now).exactly(4).times
    subject
  end
end
