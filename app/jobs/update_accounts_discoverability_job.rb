class UpdateAccountsDiscoverabilityJob < ApplicationJob
  queue_as :default
  retry_on StandardError, attempts: 1

  def perform(value)
    Account.update_all_discoverability(value)
    User.update_all_discoverability(value)
  end
end
