module TimeOffs
  class Resubmit < UseCase
    include SubjectObservable

    pattr_initialize :time_off, :attributes

    def call
      return run_callback(:success) unless time_off_modified?

      TimeOff.transaction do
        ::TimeOffs::Destroy.call(time_off)
        ::TimeOffs::Create.call(time_off_attributes) do |create|
          create.add_observers(*observers)
        end
      end
      run_callback(:success)
    end

    private

    def time_off_attributes
      time_off.attributes.merge(attributes.stringify_keys).except("approval_status")
    end

    def time_off_modified?
      time_off.slice(*attributes.keys) != attributes.stringify_keys
    end
  end
end
