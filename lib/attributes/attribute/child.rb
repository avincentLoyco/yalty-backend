module Attribute
  class Child < Person
    attribute :is_student, Boolean
    attribute :other_parent_work_status, String
    attribute :other_parent_working, Boolean

    def allowed_values
      country_codes = ISO3166::Country.codes
      {
        'other_parent_work_status' => [
          'salaried employee', 'unemployed', 'no activity', 'sick', 'injured', 'self-employed',
          'pensioner'
        ],
        'nationality' => country_codes
      }
    end
  end
end
