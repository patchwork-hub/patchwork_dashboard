class CommunityPostService < BaseService

  def call(current_user, options = {})
    @current_user = current_user
    @account = @current_user.account
    @options = options

    if @options[:id].present?
      update_community
    else
      create_community
    end

    @community
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error("Community creation/update failed: #{e.message}")
    @community
  end

  def validate_uniqueness(attribute)
    existing_community = Community.find_by(attribute => @options[attribute])
    if existing_community && existing_community.id != @options[:id].to_i
      @community ||= Community.new(community_attributes)
      @community.errors.add(attribute, "has already been taken")
      @community
    end
  end

  def create_community
    ActiveRecord::Base.transaction do
      validate_collection
      validate_community_type
      validate_uniqueness(:name)
      validate_uniqueness(:slug)
      return @community if @community&.errors&.any?

      @community = Community.new(community_attributes)
      @community.save!
      set_default_additional_information
      assign_roles_and_content_type
      # FollowBlueskyBotJob.perform_now(@community.id) if @community&.community_admins&.last&.is_boost_bot
      @community
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Community creation failed: #{e.message}")
    @community
  end

  def update_community
    ActiveRecord::Base.transaction do
      @community = Community.find_by(id: @options[:id])
      validate_collection
      validate_community_type
      validate_uniqueness(:name)
      validate_uniqueness(:slug)
      return @community if @community&.errors&.any?
      set_default_additional_information

      @community.update!(community_attributes)
      FollowBlueskyBotJob.perform_now(@community.id) if @community&.community_admins&.last&.is_boost_bot
      if @community.channel_feed?
        set_clean_up_policy
      end
      @community
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Community update failed: #{e.message}")
    @community
  end

  def validate_collection
    @collection = Collection.find_by(id: @options[:collection_id])
    handle_not_found('Collection') if @collection.nil?
  end

  def validate_community_type
    @community_type = CommunityType.find_by(id: @options[:community_type_id])
    handle_not_found('Community Type') if @community_type.nil?
  end

  def set_default_additional_information
    additional_info = @community.patchwork_community_additional_informations.first

    if @options[:bio].present?
      bio = strip_tags(@options[:bio])
      if additional_info.nil?
        @community.patchwork_community_additional_informations.create(
          heading: "Additional Information",
          text: bio
        )
      elsif additional_info.text != bio
        additional_info.update(
          heading: "Additional Information",
          text: bio
        )
      end
    end
  end

  def assign_roles_and_content_type
    if @current_user.user_admin?
      update_account_attributes
      create_community_admin
      create_default_content_type
      set_clean_up_policy
      @community.update(channel_type: 'channel_feed')
    else
      @community.update(channel_type: 'channel')
    end
  end

  def update_account_attributes
    p "START_UPDATING_ACCOUNT #{@community.slug.underscore}"
    if @options[:id].present?
      @account.update!(
        avatar: @community.avatar_image || '',
        header: @community.banner_image || ''
      )
    else
      @account.update!(
        display_name: @community.name,
        username: @community.slug.underscore,
        avatar: @community.avatar_image || '',
        header: @community.banner_image || '',
        actor_type: "Service",
        discoverable: true
      )
    end
  end

  def create_community_admin
    @community.community_admins.create(
      account_id: @account.id,
      username: @account.username,
      display_name: @community.name,
      email: @current_user.email,
      role: @current_user&.role&.name,
      is_boost_bot: true
    )
  end

  def create_default_content_type
    return if @community.content_type.present?

    @community.create_content_type(
      channel_type: 'custom_channel',
      custom_condition: 'OR'
    )
  end

  def set_clean_up_policy
    policy = AccountStatusesCleanupPolicy.find_or_initialize_by(account_id: @account.id)
    policy.assign_attributes(enabled: true, min_status_age: 1.week.seconds)
    policy.save!
  end

  def community_attributes
    attributes = {
      description: @options[:bio],
      is_recommended: @options[:is_recommended],
      guides: nil,
      patchwork_collection_id: @collection.id,
      position: get_position,
      admin_following_count: 0,
      patchwork_community_type_id: @community_type.id
    }

    if @options[:id].nil? || (!@community&.visibility&.present? && !@current_user.user_admin?)
      attributes[:name] = @options[:name]
      attributes[:slug] = @options[:slug]
    end

    if @options[:avatar_image].nil?
      @community&.avatar_image = nil
      @community&.avatar_image_file_name = nil
    else
      attributes[:avatar_image] = @options[:avatar_image]
    end

    if @options[:banner_image].nil?
      @community&.banner_image = nil
      @community&.banner_image_file_name = nil
    else
      attributes[:banner_image] = @options[:banner_image]
    end

    attributes.compact
  end

  def handle_not_found(resource_name)
    raise ActiveRecord::RecordNotFound, "#{resource_name} not found"
  end

  def get_position
    last_position = Community.order(:position).pluck(:position).last
    (last_position || 0) + 1
  end
end
