class NewslettersController < ApplicationController
  protect_from_forgery with: :null_session
  include NewsletterRules

  def create
    verified_params(gate_rules) do |attributes|
      intercom_client
        .contacts
        .create(attributes)

      render_no_content
    end
  end

  private

  def intercom_client
    @intercom_client ||= Intercom::Client.new(
      app_id: ENV['INTERCOM_APP_ID'],
      api_key: ENV['INTERCOM_API_KEY']
    )
  end
end
