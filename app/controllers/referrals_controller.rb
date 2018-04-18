class ReferralsController < ApplicationController
  include ReferrersSchemas

  protect_from_forgery with: :null_session

  def referrers_csv
    verified_dry_params(referrers_csv_schema) do |attributes|
      csv_file = generate_csv(attributes[:from], attributes[:to])
      filename = "referrers-#{Time.zone.now.to_s.tr(" ", "-")}.csv"

      respond_to do |format|
        format.csv { send_data csv_file, filename: filename }
      end
    end
  end

  def create
    verified_dry_params(dry_validation_schema) do |attributes|
      referrer = Referrer.find_or_create_by!(email: attributes[:email])

      create_or_update_intercom_lead!(attributes[:email], referrer)

      render json: { email: referrer.email, referral_token: referrer.token }
    end
  end

  private

  def create_or_update_intercom_lead!(email, referrer)
    return if intercom_client.users.find_all(email: email).present?

    lead = intercom_client.contacts.find_all(email: email).first

    if lead.present? && !lead.custom_attributes["referral_token"].present?
      lead.custom_attributes["referral_token"] = referrer.token
      intercom_client.contacts.save(lead)
    elsif !lead.present?
      lead = intercom_client.contacts.create(
        email: attributes[:email],
        custom_attributes: { referral_token: referrer.token }
      )
    end

    intercom_client.tags.tag(name: "referral_program", users: [{ id: lead.id }])
  end

  def intercom_client
    @intercom_client ||= Intercom::Client.new(token: ENV["INTERCOM_ACCESS_TOKEN"])
  end

  def generate_csv(from = nil, to = nil)
    from = from.in_time_zone.beginning_of_day if from.present?
    to   = to.in_time_zone.end_of_day if to.present?

    CSV.generate do |csv|
      csv << ["from:", from, "to:", to].compact

      column_names = %w(email token referred_accounts_count)
      csv << column_names

      Referrer.with_referred_accounts_count(from, to).each do |referrer|
        next unless referrer.referred_accounts_count.positive?
        csv << column_names.map { |attr| referrer.send(attr) }
      end
    end
  end
end
