require 'rails_helper'
require 'rake'

RSpec.describe 'generate:registration_key_token', type: :rake do
  before(:each) do
    allow_any_instance_of(IO).to receive(:puts) { '' }
  end

  context 'it generates number of tokens depending on user input' do
    before { expect(STDIN).to receive(:gets).and_return('4') }

    it { expect { subject.execute }.to change { Account::RegistrationKey.count }.by(4) }
  end

  context 'by default it generates 10 tokens' do
    before { expect(STDIN).to receive(:gets).and_return('') }

    it { expect { subject.execute }.to change { Account::RegistrationKey.count }.by(10) }
  end

  context 'it creates tokens when decimal number given' do
    before { expect(STDIN).to receive(:gets).and_return('1.2') }

    it { expect { subject.execute }.to change { Account::RegistrationKey.count }.by(1) }
  end

  context 'it does not create tokens when negative number given' do
    before { expect(STDIN).to receive(:gets).and_return('-1') }

    it { expect { subject.execute }.to_not change { Account::RegistrationKey.count } }
  end

  context 'it does not create tokens when invalid number given' do
    before { expect(STDIN).to receive(:gets).and_return('abc') }

    it { expect { subject.execute }.to_not change { Account::RegistrationKey.count } }
  end
end