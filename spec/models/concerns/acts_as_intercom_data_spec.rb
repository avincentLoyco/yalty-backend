require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe ActsAsIntercomData do
  let(:redis) { Resque.redis }
  let(:create_account) { create(:account) }

  context 'when queue is empty' do
    it 'puts a job in the queue' do
      expect { create_account }.to change { redis.keys('timestamps:*').size }.by(1)
    end
  end

  context 'when there is a job on the queue' do
    before { create_account }

    it 'does not put another job on the queue' do
      expect {
        create_account.update!(company_name: 'Los Pollos Hermanos')
      }.to_not change { redis.keys('timestamps:*').size }
    end
  end
end
