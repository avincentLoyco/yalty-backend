module AuthHelper
  def referral_http_login
    user = ENV['REFERRAL_USER']
    pw = ENV['REFERRAL_PASSWORD']
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user,pw)
  end
end

module AuthRequestHelper
  #
  # pass the @env along with your request, eg:
  #
  # GET '/labels', {}, @env
  #
  def referral_http_login
    @env ||= {}
    user = ENV['REFERRAL_USER']
    pw = ENV['REFERRAL_PASSWORD']
    @env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user,pw)
  end
end
