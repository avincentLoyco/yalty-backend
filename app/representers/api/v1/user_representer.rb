module Api::V1
  class UserRepresenter < BaseRepresenter
    def complete
      {
        email:            resource.email,
        locale:           resource.locale,
        balance_in_hours: resource.balance_in_hours,
        role:             resource.role,
        referral_token:   resource.referrer.try(:token),
      }
        .merge(basic)
        .merge(relationships)
    end

    def session
      {
        locale:           resource.locale,
        balance_in_hours: resource.balance_in_hours,
        role:             resource.role,
      }
        .merge(basic)
        .merge(intercom_hash)
        .merge(relationships)
    end

    def relationships
      {
        employee: employee_json,
      }
    end

    def intercom_hash
      return {} if resource.role.eql?("yalty")

      {
        intercom_hash: OpenSSL::HMAC.hexdigest(
          "sha256",
          ENV["INTERCOM_SECRET_KEY"],
          resource.id
        ),
      }
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end
  end
end
