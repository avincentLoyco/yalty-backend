require 'rails_helper'
require 'fakeredis/rspec'

RSpec.describe ActsAsIntercomData do
  let(:redis) { Resque.redis }
  let(:create_account) { create(:account) }

  context 'when queue is empty' do
    it { expect(redis.keys).to be_empty }

    it 'puts a job in the queue' do
      create_account
      expect(redis.keys('delayed:*').size).to eq(1)
    end
  end

  context 'when there is a job on the queue' do
    before { create_account }

    it { expect(redis.keys('delayed:*').size).to eq(1) }

    it 'does not put another job on the queue' do
      create_account.update!(company_name: 'Los Pollos Hermanos')
      expect(redis.keys('delayed:*').size).to eq(1)
    end
  end
end
