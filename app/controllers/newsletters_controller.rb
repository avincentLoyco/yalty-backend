class NewslettersController < ApplicationController
  protect_from_forgery with: :null_session
  include NewsletterSchemas

  def create
    verified_dry_params(dry_validation_schema) do |attributes|
      lead = intercom_client.contacts.find_all(email: attributes[:email]).first

      if lead
        lead.custom_attributes['newsletter_language'] = attributes[:language]
        intercom_client.contacts.save(lead)
      else
        lead = intercom_client.contacts.create(
          email: attributes[:email],
          name: attributes[:name],
          custom_attributes: {
            newsletter_language: attributes[:language]
          }
        )
      end

      intercom_client.tags.tag(name: 'newsletter', users: [{ id: lead.id }])

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
