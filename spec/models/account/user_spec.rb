require 'rails_helper'

RSpec.describe Account::User, type: :model do
  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:email).with_options(null: false) }
  it { is_expected.to have_db_index([:email, :account_id]).unique(true) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to allow_value('test@test.com').for(:email) }
  it { is_expected.to_not allow_value('testtest.com').for(:email) }
  it { is_expected.to_not allow_value('testtestcom').for(:email) }
  it { is_expected.to_not allow_value('test@testcom').for(:email) }

  it { is_expected.to have_db_column(:password_digest).with_options(null: false) }
  it { is_expected.to validate_presence_of(:password) }
  it { is_expected.to validate_confirmation_of(:password) }
  it { is_expected.to validate_length_of(:password).is_at_least(8).is_at_most(74) }

  it 'should validate length of password only when is updated' do
    user = create(:account_user)
    user = Account::User.find(user.id)

    expect(user).to be_valid
  end

  it { should have_db_column(:account_id).of_type(:uuid) }
  it { should have_db_index(:account_id) }
  it { should belong_to(:account).inverse_of(:users) }

  it '#current= should accept an user' do
    user = create(:account_user)

    expect(Account::User).to respond_to(:current=)
    expect {
      Account::User.current = user
    }.to_not raise_error
  end

  it '#current should return user' do
    user = create(:account_user)
    Account::User.current = user

    expect(Account::User.current).to eql(user)
  end
end
