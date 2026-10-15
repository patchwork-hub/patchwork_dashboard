require 'test_helper'

class StarterPackPolicyTest < ActiveSupport::TestCase
  test 'all actions require administrator or starter pack permission' do
    permitted = User.new(role: UserRole.create!(name: 'Pack manager', permissions: UserRole::FLAGS[:manage_starter_packs]))
    admin = User.new(role: UserRole.create!(name: 'Admin', permissions: UserRole::FLAGS[:administrator]))
    denied = User.new(role: UserRole.create!(name: 'Reader', permissions: 0))
    %i[index? show? new? create? edit? update? destroy? search_accounts? next_position? add_account? remove_account? reorder? reorder_accounts?].each do |action|
      assert StarterPackPolicy.new(permitted, :starter_pack).public_send(action)
      assert StarterPackPolicy.new(admin, :starter_pack).public_send(action)
      assert_not StarterPackPolicy.new(denied, :starter_pack).public_send(action)
    end
  end
end