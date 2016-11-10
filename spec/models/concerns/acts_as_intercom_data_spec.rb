require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe ActsAsIntercomData do
  let(:create_account) { create(:account) }

  context 'when queue is empty' do
    it 'puts a job in the queue' do
      expect { create_account }.to change { SendDataToIntercom.jobs.count }.by(1)
    end
  end

  context 'when there is a job on the queue' do
    before { create_account }

    it 'does not put another job on the queue' do
      expect { create_account }.to_not change { SendDataToIntercom.jobs.count }
    end
  end
end
