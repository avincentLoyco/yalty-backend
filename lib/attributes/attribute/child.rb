module Attribute
  class Child < Person
    attribute :is_student, Boolean
    attribute :other_parent_work_status, String
    attribute :other_parent_working, Boolean

    def allowed_values
      {
        'other_parent_work_status' => [
          'salaried employee', 'unemployed', 'no activity', 'sick', 'injured', 'self-employed',
          'pensioner'
        ]
      }
    end
  end
end
