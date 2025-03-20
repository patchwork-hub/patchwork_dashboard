class Community < ApplicationRecord
  self.table_name = 'patchwork_communities'

  IMAGE_MIME_TYPES = ['image/svg+xml', 'image/png', 'image/jpeg', 'image/jpg'].freeze
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
    length: { maximum: NAME_LENGTH_LIMIT, too_long: "cannot be longer than %{count} characters" }

  validates :slug, presence: true,
    length: { minimum: MINIMUM_SLUG_LENGTH, maximum: SLUG_LENGTH_LIMIT,
              too_short: "must be at least %{count} characters",
              too_long: "cannot be longer than %{count} characters" }

  validate :slug_cannot_be_changed, on: :update

  validate :conditional_slug_format

  def conditional_slug_format
    regex = is_custom_domain? ? /\A[a-z][a-z0-9.-]*[a-z0-9]\z/i : /\A[a-z][a-z0-9-]*[a-z0-9]\z/i

    unless slug =~ regex
    message = if is_custom_domain?
      "must start with a letter, can include letters, numbers, hyphens, and dots, but cannot end with a hyphen or dot"
    else
      "must start with a letter, can include letters, numbers, and hyphens, but cannot end with a hyphen"
    end
    errors.add(:slug, message)
    end
  end

  def slug_cannot_be_changed
    if slug_changed? && persisted?
      errors.add(:slug, "cannot be updated")
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
            foreign_key: 'patchwork_collection_id'

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

  validates :name, presence: true, uniqueness: true

  validates :registration_mode, inclusion: { in: ['open', 'approved', 'none'] }

  scope :recommended, -> {
    joins(:patchwork_community_type)
      .where(patchwork_communities: { is_recommended: true })
      .filter_channels
      .exclude_array_ids
      .exclude_incomplete_channels
      .order('patchwork_community_types.sorting_index ASC')
  }

  scope :ordered_pos_name, -> { order('patchwork_communities.position ASC, patchwork_communities.name ASC') }

  scope :filter_channels, -> { where(patchwork_communities: { channel_type: Community.channel_types[:channel] }) }

  scope :filter_channel_feeds, -> { where(patchwork_communities: { channel_type: Community.channel_types[:channel_feed] }) }

  scope :exclude_incomplete_channels, -> { where.not(patchwork_communities: { visibility: nil }) }

  enum visibility: { public_access: 0, guest_access: 1, private_local: 2 }

  scope :exclude_array_ids, -> { where.not(id: EXCLUDE_ARRAY_IDS) }

  enum channel_type: { channel: 'channel', channel_feed: 'channel_feed', hub: 'hub' }

  def self.ransackable_attributes(auth_object = nil)
    ["name"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  private

  def unique_patchwork_community_links
    urls = patchwork_community_links.reject(&:marked_for_destruction?).map(&:url)
    duplicate_urls = urls.select { |url| urls.count(url) > 1 }.uniq

    if duplicate_urls.any?
      errors.add(:base, "Links contains duplicate URLs: #{duplicate_urls.join(', ')}")
    end
  end
end
