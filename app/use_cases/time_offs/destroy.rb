module TimeOffs
  class Destroy < UseCase
    pattr_initialize :time_off

    def call
      TimeOff.transaction do
        TimeOffs::Decline.call(time_off) do |decline|
          decline.on(:success) do
            return destroy_declined
          end
          decline.on(:not_modified) do
            return destroy_declined
          end
        end
      end
    end

    private

    def destroy_declined
      ::Notification.where(resource: time_off).destroy_all
      time_off.destroy!

      run_callback(:success)
    end
  end
end
