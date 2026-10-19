# == Schema Information
#
# Table name: patchwork_starter_packs
#
#  id             :bigint           not null, primary key
#  description    :text
#  instance_name  :string           not null
#  position       :integer          default(0), not null
#  title          :string           not null
#  total_accounts :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  created_by_id  :bigint
#
# Indexes
#
#  index_patchwork_starter_packs_on_created_by_id               (created_by_id)
#  index_patchwork_starter_packs_on_instance_name_and_position  (instance_name,position)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => accounts.id) ON DELETE => nullify
#
require 'test_helper'

class StarterPackTest < ActiveSupport::TestCase
  test 'display order accepts explicit values on create and update' do
    pack = StarterPack.create!(title: 'Manual order', instance_name: 'manualorder', position: 0)
    assert_equal 0, pack.reload.position
    pack.update!(position: 7)
    assert_equal 7, pack.reload.position
    pack.update!(instance_name: 'anotherinstance', position: 3)
    assert_equal 3, pack.reload.position
  end

  test 'duplicate display order is rejected only within the same instance' do
    StarterPack.create!(title: 'First', instance_name: 'manualorder', position: 4)
    duplicate = StarterPack.new(title: 'Duplicate', instance_name: 'manualorder', position: 4)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:position], 'has already been taken'
    duplicate.instance_name = 'anotherinstance'
    assert duplicate.valid?
  end

  test 'normalizes instances and requires a title and instance' do
    pack = StarterPack.create!(title: 'Example', instance_name: 'Find Out')
    assert_equal 'findout', pack.instance_name
    assert_includes StarterPack.for_instance('Find Out'), pack
    assert_not StarterPack.new(title: '', instance_name: '---').valid?
  end

  test 'creator is explicitly assigned and can be a remote account' do
    account = Account.create!(username: 'packcreator', display_name: 'Creator', domain: 'example.org')
    pack = StarterPack.create!(title: 'Example', instance_name: 'twt', created_by: account)
    assert_equal account, pack.created_by
    assert_nil StarterPack.new.created_by
    pack.update!(created_by: nil)
    assert_nil pack.reload.created_by
  end

  test 'membership is unique and ordered and deleted with the pack' do
    pack = StarterPack.create!(title: 'Example', instance_name: 'twt')
    first = Account.create!(username: 'packfirst', display_name: 'First', domain: 'example.org')
    second = Account.create!(username: 'packsecond', display_name: 'Second', domain: 'example.org')
    pack.starter_pack_accounts.create!(account: first, position: 2)
    pack.starter_pack_accounts.create!(account: second, position: 1)
    assert_equal [second, first], pack.accounts.to_a
    assert_not pack.starter_pack_accounts.build(account: first).valid?
    pack.destroy!
    assert_empty StarterPackAccount.where(patchwork_starter_pack_id: pack.id)
  end

  test 'database nullifies creator and cascades account membership on deletion' do
    account = Account.create!(username: 'packdeleted', display_name: 'Deleted', domain: 'example.org')
    pack = StarterPack.create!(title: 'Example', instance_name: 'twt', created_by: account)
    pack.starter_pack_accounts.create!(account: account)
    account.delete
    assert_nil pack.reload.created_by_id
    assert_empty pack.starter_pack_accounts.reload
  end
end
