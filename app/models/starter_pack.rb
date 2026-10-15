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
#  index_patchwork_starter_packs_on_created_by_id  (created_by_id)
#  unique_starter_pack_instance_position           (instance_name,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => accounts.id) ON DELETE => nullify
#
class StarterPack < ApplicationRecord
  self.table_name = 'patchwork_starter_packs'

  belongs_to :created_by, class_name: 'Account', optional: true
  has_many :starter_pack_accounts, -> { order(:position, :id) }, foreign_key: :patchwork_starter_pack_id, dependent: :delete_all
  has_many :accounts, through: :starter_pack_accounts

  before_validation :normalize_instance_name
  around_save :assign_display_order, if: -> { (new_record? || will_save_change_to_instance_name?) && !position_came_from_user? }
  validates :title, :instance_name, presence: true
  validates :created_by, presence: true, if: -> { created_by_id.present? }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: :instance_name }, if: :position_came_from_user?
  scope :for_instance, ->(name) { where(instance_name: name.to_s.parameterize(separator: '')) }
  scope :ordered, -> { order(:position, :id) }

  def self.next_position_for(instance_name)
    packs = instance_name.present? ? for_instance(instance_name) : all
    (packs.maximum(:position) || 0) + 1
  end

  def self.with_order_lock
    transaction do
      connection.execute('SELECT pg_advisory_xact_lock(4250145001)')
      yield
    end
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[title instance_name]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def assign_display_order
    self.class.with_order_lock do
      self.position = self.class.next_position_for(instance_name)
      yield
    end
  end

  def normalize_instance_name
    self.instance_name = instance_name.to_s.parameterize(separator: '')
  end
end
