# == Schema Information
#
# Table name: patchwork_communities
#
#  id                          :bigint           not null, primary key
#  about                       :string
#  admin_following_count       :integer          default(0)
#  avatar_image_content_type   :string
#  avatar_image_file_name      :string
#  avatar_image_file_size      :bigint
#  avatar_image_updated_at     :datetime
#  banner_image_content_type   :string
#  banner_image_file_name      :string
#  banner_image_file_size      :bigint
#  banner_image_updated_at     :datetime
#  channel_type                :string           default("channel"), not null
#  deleted_at                  :datetime
#  description                 :string
#  did_value                   :string
#  guides                      :jsonb
#  is_custom_domain            :boolean          default(FALSE), not null
#  is_recommended              :boolean          default(FALSE), not null
#  logo_image_content_type     :string
#  logo_image_file_name        :string
#  logo_image_file_size        :bigint
#  logo_image_updated_at       :datetime
#  name                        :string           not null
#  no_boost_channel            :boolean          default(FALSE)
#  participants_count          :integer          default(0)
#  position                    :integer          default(0)
#  post_visibility             :integer          default("followers_only"), not null
#  registration_mode           :string           default("none")
#  slug                        :string           not null
#  visibility                  :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  ip_address_id               :bigint
#  patchwork_collection_id     :bigint
#  patchwork_community_type_id :bigint
#
# Indexes
#
#  index_patchwork_communities_on_ip_address_id                (ip_address_id)
#  index_patchwork_communities_on_name                         (name) UNIQUE
#  index_patchwork_communities_on_patchwork_collection_id      (patchwork_collection_id)
#  index_patchwork_communities_on_patchwork_community_type_id  (patchwork_community_type_id)
#  index_patchwork_communities_on_slug                         (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (patchwork_collection_id => patchwork_collections.id)
#
class Community < ApplicationRecord
  self.table_name = 'patchwork_communities'

  IMAGE_MIME_TYPES = ['image/svg+xml', 'image/png', 'image/jpeg', 'image/jpg', 'image/webp'].freeze
  LIMIT = 2.megabytes

  NAME_LENGTH_LIMIT = 30
  SLUG_LENGTH_LIMIT = 30
  MINIMUM_SLUG_LENGTH = 2
  DESCRIPTION_LENGTH_LIMIT = 500
  EXCLUDE_ARRAY_IDS = []

  has_attached_file :logo_image
  has_attached_file :avatar_image
  has_attached_file :banner_image

  attribute :is_custom_domain, :boolean, default: false

  validates :name, presence: true,
    length: { maximum: NAME_LENGTH_LIMIT, too_long: I18n.t('activerecord.errors.models.community.attributes.name.too_long') },
    uniqueness: { case_sensitive: false, message: I18n.t('activerecord.errors.models.community.attributes.name.taken') }

  validates :slug, presence: true,
    length: { minimum: MINIMUM_SLUG_LENGTH, maximum: SLUG_LENGTH_LIMIT,
              too_short: I18n.t('activerecord.errors.models.community.attributes.slug.too_short'),
              too_long: I18n.t('activerecord.errors.models.community.attributes.slug.too_long') }

  validate :slug_cannot_be_changed, on: :update

  validate :conditional_slug_format

  def conditional_slug_format
    custom_domain = ActiveModel::Type::Boolean.new.cast(self[:is_custom_domain])

    regex = if custom_domain
      /\A[a-zA-Z0-9]+([-a-zA-Z0-9]*\.[a-zA-Z0-9]+)*\z/
    else
      /\A[a-z][a-z0-9-]*[a-z0-9]\z/i
    end

    unless slug =~ regex
      message = if custom_domain
        I18n.t('activerecord.errors.models.community.attributes.slug.invalid_domain',
               default: "must be a valid domain format (e.g., example.com), cannot have consecutive dots or end with a dot")
      else
        I18n.t('activerecord.errors.models.community.attributes.slug.invalid',
               default: "must start with a letter, can include letters, numbers, and hyphens, but cannot end with a hyphen")
      end
      errors.add(:slug, message)
    end
  end


  def slug_cannot_be_changed
    if slug_changed? && persisted?
      errors.add(:slug, I18n.t('activerecord.errors.models.community.attributes.slug.immutable',
                              default: "cannot be updated"))
    end
  end

  def formatted_error_messages
    errors.full_messages.map do |msg|
      if msg.start_with?("Slug")
        if is_custom_domain?
          msg.sub("Slug", "Custom domain")
        else
          msg.sub("Slug", "Channel username")
        end
      else
        msg
      end
    end
  end

  validates :description, length: { maximum: DESCRIPTION_LENGTH_LIMIT, too_long: "cannot be longer than %{count} characters" }

  validates_attachment :logo_image,
                       content_type: { content_type: IMAGE_MIME_TYPES },
                       size: { less_than: LIMIT }

  validates_attachment :avatar_image,
                       content_type: { content_type: IMAGE_MIME_TYPES },
                       size: { less_than: LIMIT }

  validates_attachment :banner_image,
                       content_type: { content_type: IMAGE_MIME_TYPES },
                       size: { less_than: LIMIT }

  has_many :community_admins,
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  has_many :patchwork_community_additional_informations,
            class_name: 'CommunityAdditionalInformation',
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  accepts_nested_attributes_for :patchwork_community_additional_informations, allow_destroy: true

  has_one :community_post_type,
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  belongs_to :patchwork_collection,
            class_name: 'Collection',
            foreign_key: 'patchwork_collection_id',
            optional: true

  belongs_to :patchwork_community_type,
              class_name: 'CommunityType',
              foreign_key: 'patchwork_community_type_id'

  has_one :content_type,
            class_name: 'ContentType',
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  has_many :patchwork_community_links,
            class_name: 'CommunityLink',
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  validate :unique_patchwork_community_links

  has_many :patchwork_community_rules,
            class_name: 'CommunityRule',
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  has_many :patchwork_community_filter_keywords,
            class_name: 'CommunityFilterKeyword',
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  has_many :patchwork_community_hashtags,
            class_name: 'CommunityHashtag',
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  has_many :joined_communities,
            class_name: 'JoinedCommunity',
            foreign_key: 'patchwork_community_id',
            dependent: :destroy

  accepts_nested_attributes_for :patchwork_community_rules, allow_destroy: true

  has_many :social_links, -> { social }, class_name: 'CommunityLink', foreign_key: 'patchwork_community_id'
  has_many :general_links, -> { general }, class_name: 'CommunityLink', foreign_key: 'patchwork_community_id'

  accepts_nested_attributes_for :social_links, allow_destroy: true
  accepts_nested_attributes_for :general_links, allow_destroy: true

  belongs_to :ip_address, optional: true

  validates :registration_mode, inclusion: { in: ['open', 'approved', 'none'] }

  scope :recommended, -> {
    joins(:patchwork_community_type)
      .where(patchwork_communities: { is_recommended: true })
      .filter_channels
      .exclude_array_ids
      .exclude_incomplete_channels
      .exclude_deleted_channels
      .order('patchwork_community_types.sorting_index ASC')
  }

  scope :ordered_pos_name, -> { order('patchwork_communities.name ASC') }

  scope :filter_channels, -> { where(patchwork_communities: { channel_type: Community.channel_types[:channel] }).exclude_deleted_channels }

  scope :filter_channel_feeds, -> { where(patchwork_communities: { channel_type: Community.channel_types[:channel_feed] }).exclude_deleted_channels }

  scope :filter_newsmast_channels, -> { where(patchwork_communities: { channel_type: Community.channel_types[:newsmast] }).exclude_deleted_channels }

  scope :exclude_incomplete_channels, -> { where.not(patchwork_communities: { visibility: nil }).exclude_deleted_channels }

  scope :exclude_not_recommended, -> { where.not(patchwork_communities: { is_recommended: false }) }

  scope :exclude_deleted_channels, -> { where(patchwork_communities: { deleted_at: nil }) }

  enum visibility: { public_access: 0, guest_access: 1, private_local: 2 }

  scope :exclude_array_ids, -> { where.not(id: EXCLUDE_ARRAY_IDS) }

  scope :not_deleted, -> { where(deleted: nil) }

  scope :with_all_includes, -> {
  includes(
    :content_type,
    :patchwork_community_type,
    :patchwork_community_hashtags,
    :patchwork_community_rules,
    :patchwork_community_additional_informations,
    :patchwork_community_links
  )
}

  enum channel_type: { channel: 'channel', channel_feed: 'channel_feed', hub: 'hub', newsmast: 'newsmast'}

  enum post_visibility: { public_visibility: 0, unlisted: 1, followers_only: 2, direct: 3 }

  def self.ransackable_attributes(auth_object = nil)
    ["name"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete!
    update(deleted_at: Time.current)
  end

  def recover!
    update(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def recoverable?
    deleted_at && deleted_at > 30.days.ago
  end

  def self.has_local_newsmast_channel?
    self.filter_newsmast_channels.present?
  end

  private

  def unique_patchwork_community_links
    urls = patchwork_community_links.reject(&:marked_for_destruction?).map(&:url)
    duplicate_urls = urls.select { |url| urls.count(url) > 1 }.uniq

    if duplicate_urls.any?
      errors.add(:base, I18n.t('activerecord.errors.models.community.attributes.base.duplicate_link_urls', 
                              urls: duplicate_urls.join(', '), 
                              default: "Links contains duplicate URLs: #{duplicate_urls.join(', ')}"))
    end
  end
end
