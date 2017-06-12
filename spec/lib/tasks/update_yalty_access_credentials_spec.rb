require 'rails_helper'
require 'rake'

RSpec.describe 'update_yalty_access_credentials', type: :rake do
  include_context 'shared_context_account_helper'
  include_context 'rake'

  before do
    ENV['YALTY_ACCESS_EMAIL'] = 'old@example.com'
    create_list(:account_user, 3, :with_yalty_role,
      email: 'old@example.com',
      password: 'oldpassword'
    )
  end

  it  'should update email' do
    ENV['YALTY_ACCESS_EMAIL'] = 'access@example.com'
    expect { subject }.to change { Account::User.where(role: 'yalty').pluck(:email).join }
  end

  it  'should update password' do
    ENV['YALTY_ACCESS_PASSWORD_DIGEST'] = BCrypt::Password.create('1234567890', cost: 10)
    expect { subject }.to change { Account::User.where(role: 'yalty').pluck(:password_digest).join }
  end
end
