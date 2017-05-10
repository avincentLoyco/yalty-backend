require 'rails_helper'
require 'rake'

RSpec.describe 'payments:update_available_modules', type: :rake do
  include_context 'rake'

  before do
    create_list(:account, 4)
    create_list(:account, 4, :with_stripe_fields)
    create_list(:account, 4, :with_stripe_fields, :with_available_modules)

    allow(::Payments::UpdateAvailableModules).to receive(:perform_later)
  end

  it 'schedules a job for every account with available modules' do
    expect(::Payments::UpdateAvailableModules).to receive(:perform_later).exactly(4).times
    subject
  end
end
