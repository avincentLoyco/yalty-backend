require 'rails_helper'

RSpec.describe Account::User, type: :model do
  it { should have_db_column(:email).with_options(null: false) }
  it { should have_db_index([:email, :account_id]).unique(true) }
  it { should validate_presence_of(:email) }

  it { should have_db_column(:password_digest).with_options(null: false) }
  it { should validate_presence_of(:password) }
  it { should validate_confirmation_of(:password) }
  it { should validate_length_of(:password).is_at_least(8).is_at_most(74) }

  it 'should validate length of password only when is updated' do
    user = create(:account_user)
    user = Account::User.find(user.id)

    expect(user).to be_valid
  end

  it { should have_db_column(:account_id) }
  it { should have_db_index(:account_id) }
  it { should belong_to(:account).inverse_of(:users) }
end
