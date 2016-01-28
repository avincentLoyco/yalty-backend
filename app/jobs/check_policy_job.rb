class CheckPolicyJob < ActiveJob::Base
  @queue = :check_policy_job

  def perform

  end
end
