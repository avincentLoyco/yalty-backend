module Api::V1
  class UserRepresenter < BaseRepresenter
    def complete
      {
        email:          resource.email,
        locale:         resource.locale,
        role:           resource.role,
        referral_token: resource.referrer.try(:token)
      }
        .merge(basic)
        .merge(relationships)
    end

    def session
      {
        locale:        resource.locale,
        role:          resource.role,
        intercom_hash: OpenSSL::HMAC.hexdigest(
          'sha256',
          ENV['INTERCOM_SECRET_KEY'],
          resource.id
        )
      }
        .merge(basic)
        .merge(relationships)
    end

    def relationships
      {
        employee: employee_json
      }
    end

    def employee_json
      EmployeeRepresenter.new(resource.employee).basic
    end
  end
end
