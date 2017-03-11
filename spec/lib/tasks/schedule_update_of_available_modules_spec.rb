require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'
require 'rake'

RSpec.describe 'schedule_update_of_available_modules', type: :rake do
  let(:rake)      { Rake::Application.new }
  let(:task_name) { self.class.top_level_description }
  let(:task_path) { "lib/tasks/#{task_name.split(":").first}" }
  let(:task_path_2) { "lib/tasks/create_customers_for_existing_accounts" }
  subject { rake['payments:schedule_update_of_available_modules'].invoke }

  let!(:acounts_with_stripe) { create_list(:account, 4, :with_stripe_fields) }
  let!(:acounts_without_stripe) { create_list(:account, 4) }

  def loaded_files_excluding_current_rake_file(path)
    $".reject { |file| file == Rails.root.join("#{path}.rake").to_s }
  end

  before do
    Rake.application = rake
    Rake.application.rake_require(
      task_path,
      [Rails.root.to_s],
      loaded_files_excluding_current_rake_file(task_path)
    )
    Rake.application.rake_require(
      task_path_2,
      [Rails.root.to_s],
      loaded_files_excluding_current_rake_file(task_path_2)
    )
    Rake::Task.define_task(:environment)
    allow(::Payments::UpdateAvailableModules).to receive(:perform_now)
    allow(::Payments::CreateCustomerWithSubscription).to receive(:perform_now)
  end

  it 'schedules a job for every account with customer and subscription' do
    expect(::Payments::UpdateAvailableModules).to receive(:perform_now).exactly(4).times
    subject
  end

  it 'schedules a CreateCustomerWithSubscription job for every account without stripe' do
    expect(::Payments::CreateCustomerWithSubscription).to receive(:perform_now).exactly(4).times
    subject
  end
end
