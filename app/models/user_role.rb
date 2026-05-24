
# == Schema Information
#
# Table name: user_roles
#
#  id          :bigint           not null, primary key
#  color       :string           default(""), not null
#  highlighted :boolean          default(FALSE), not null
#  name        :string           default(""), not null
#  permissions :bigint           default(0), not null
#  position    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class UserRole < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Mastodon permission flags (bits 0–20) — kept in sync with patchwork-mastodon
  # ---------------------------------------------------------------------------
  FLAGS = {
    administrator:        (1 << 0),
    view_devops:          (1 << 1),
    view_audit_log:       (1 << 2),
    view_dashboard:       (1 << 3),
    manage_reports:       (1 << 4),
    manage_federation:    (1 << 5),
    manage_settings:      (1 << 6),
    manage_blocks:        (1 << 7),
    manage_taxonomies:    (1 << 8),
    manage_appeals:       (1 << 9),
    manage_users:         (1 << 10),
    manage_invites:       (1 << 11),
    manage_rules:         (1 << 12),
    manage_announcements: (1 << 13),
    manage_custom_emojis: (1 << 14),
    manage_webhooks:      (1 << 15),
    invite_users:         (1 << 16),
    manage_roles:         (1 << 17),
    manage_user_access:   (1 << 18),
    delete_user_data:     (1 << 19),
    view_feeds:           (1 << 20),

    # -------------------------------------------------------------------------
    # Dashboard-specific permission flags (bits 21–30)
    # -------------------------------------------------------------------------
    manage_channels:          (1 << 21),
    manage_channel_feeds:     (1 << 22),
    manage_hubs:              (1 << 23),
    manage_newsmast_channels: (1 << 24),
    manage_collections:       (1 << 25),
    manage_community_admins:  (1 << 26),
    manage_server_settings:   (1 << 27),
    manage_api_keys:          (1 << 28),
    view_accounts:            (1 << 29),
    manage_master_admins:     (1 << 30),
    manage_installation:      (1 << 31),
    manage_sidekiq:           (1 << 32),
    manage_resources:         (1 << 33),
    manage_invitation_codes:  (1 << 34),
    manage_app_versions:      (1 << 35),
    manage_global_filters:    (1 << 36),
    view_newsmast_dashboard:  (1 << 37),
  }.freeze

  EVERYONE_ROLE_ID = -99
  NOBODY_POSITION  = -1
  POSITION_LIMIT   = (2**31) - 1

  CSS_COLORS = /\A#?(?:[A-F0-9]{3}){1,2}\z/i

  # ---------------------------------------------------------------------------
  # Flags module — constants and category groupings
  # ---------------------------------------------------------------------------
  module Flags
    NONE = 0
    ALL  = FLAGS.values.reduce(:|)

    DEFAULT = FLAGS[:invite_users]

    # Mastodon categories (for reference/display)
    MASTODON_CATEGORIES = {
      invites: %i[
        invite_users
      ].freeze,

      moderation: %i[
        view_dashboard
        view_audit_log
        manage_users
        manage_user_access
        delete_user_data
        manage_reports
        manage_appeals
        manage_federation
        manage_blocks
        manage_taxonomies
        manage_invites
        view_feeds
      ].freeze,

      administration: %i[
        manage_settings
        manage_rules
        manage_roles
        manage_webhooks
        manage_announcements
      ].freeze,

      devops: %i[
        view_devops
      ].freeze,

      special: %i[
        administrator
      ].freeze,
    }.freeze

    # Dashboard-specific categories
    DASHBOARD_CATEGORIES = {
      dashboard_channels: %i[
        manage_channels
        manage_channel_feeds
        manage_hubs
        manage_newsmast_channels
      ].freeze,

      dashboard_management: %i[
        manage_collections
        manage_community_admins
        manage_server_settings
        manage_api_keys
        view_accounts
        manage_master_admins
        manage_custom_emojis
        manage_global_filters
        view_newsmast_dashboard
      ].freeze,

      dashboard_operations: %i[
        manage_installation
        manage_sidekiq
        manage_resources
        manage_invitation_codes
        manage_app_versions
      ].freeze,
    }.freeze

    CATEGORIES = MASTODON_CATEGORIES.merge(DASHBOARD_CATEGORIES).freeze
  end

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  has_many :users, inverse_of: :role, foreign_key: 'role_id', dependent: :nullify

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :name, presence: true, unless: :everyone?
  validates :color, format: { with: CSS_COLORS }, if: :color?
  validates :position, numericality: { in: (-POSITION_LIMIT..POSITION_LIMIT) }

  validate :validate_permissions_elevation
  validate :validate_position_elevation
  validate :validate_dangerous_permissions
  validate :validate_own_role_edition

  before_validation :set_position

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :assignable, -> { where.not(id: EVERYONE_ROLE_ID).order(position: :asc) }

  def self.assignable_by(user)
    return assignable if user&.role&.name == 'MasterAdmin'
    assignable.select { |role| user&.role&.overrides?(role) }
  end

  # ---------------------------------------------------------------------------
  # Attribute for privilege-escalation checks
  # ---------------------------------------------------------------------------
  attr_writer :current_account

  # ---------------------------------------------------------------------------
  # Class methods
  # ---------------------------------------------------------------------------
  def self.nobody
    @nobody ||= UserRole.new(permissions: Flags::NONE, position: NOBODY_POSITION)
  end

  def self.everyone
    UserRole.find(EVERYONE_ROLE_ID)
  rescue ActiveRecord::RecordNotFound
    UserRole.create!(id: EVERYONE_ROLE_ID, permissions: Flags::DEFAULT)
  end

  def self.that_can(*any_of_privileges)
    all.select { |role| role.can?(*any_of_privileges) }
  end

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------
  def everyone?
    id == EVERYONE_ROLE_ID
  end

  def nobody?
    id.nil?
  end

  def permissions_as_keys
    FLAGS.keys.select { |privilege| permissions & FLAGS[privilege] == FLAGS[privilege] }.map(&:to_s)
  end

  def permissions_as_keys=(value)
    self.permissions = value.filter_map(&:presence).reduce(Flags::NONE) do |bitmask, privilege|
      FLAGS.key?(privilege.to_sym) ? (bitmask | FLAGS[privilege.to_sym]) : bitmask
    end
  end

  def can?(*any_of_privileges)
    any_of_privileges.any? { |privilege| in_permissions?(privilege) }
  end

  def overrides?(other_role)
    other_role.nil? || position > other_role.position
  end

  def computed_permissions
    # If called on the everyone role, no further computation needed
    return permissions if everyone?

    # If called on the nobody role, no permissions are there to be given
    return Flags::NONE if nobody?

    # Otherwise, merge with the "everyone" role and check for administrator
    @computed_permissions ||= begin
      merged = self.class.everyone.permissions | self.permissions

      if merged & FLAGS[:administrator] == FLAGS[:administrator]
        Flags::ALL
      else
        merged
      end
    end
  end

  def dashboard_permissions_as_keys
    Flags::DASHBOARD_CATEGORIES.values.flatten.select { |privilege| can?(privilege) }.map(&:to_s)
  end

  def mastodon_permissions_as_keys
    Flags::MASTODON_CATEGORIES.values.flatten.select { |privilege| can?(privilege) }.map(&:to_s)
  end

  private

  def in_permissions?(privilege)
    raise ArgumentError, "Unknown privilege: #{privilege}" unless FLAGS.key?(privilege)

    computed_permissions & FLAGS[privilege] == FLAGS[privilege]
  end

  def set_position
    self.position = NOBODY_POSITION if everyone?
  end

  def validate_own_role_edition
    return unless defined?(@current_account) && @current_account&.role&.id == id

    errors.add(:permissions_as_keys, :own_role) if permissions_changed?
    errors.add(:position, :own_role) if position_changed?
  end

  def validate_permissions_elevation
    return unless defined?(@current_account) && @current_account.present?

    current_permissions = @current_account.role&.computed_permissions || Flags::NONE
    errors.add(:permissions_as_keys, :elevated) if current_permissions & permissions != permissions
  end

  def validate_position_elevation
    return unless defined?(@current_account) && @current_account.present?

    current_position = @current_account.role&.position || NOBODY_POSITION
    errors.add(:position, :elevated) if current_position < position
  end

  def validate_dangerous_permissions
    errors.add(:permissions_as_keys, :dangerous) if everyone? && Flags::DEFAULT & permissions != permissions
  end
end
