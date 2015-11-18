require 'rails_helper'
require 'rake'

RSpec.describe 'generate_token' do
  before(:each) do
    allow_any_instance_of(IO).to receive(:puts) { '' }
    load File.join(Rails.root, 'lib/tasks/generate_token.rake')
    Rake::Task.define_task(:environment)
  end

  subject { Rake::Task['generate_token'] }

  it { expect { subject.invoke }.to change { Account::RegistrationKey.count }.by(10) }
end
