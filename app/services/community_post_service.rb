class CommunityPostService < BaseService

  def call(current_user, options = {})
    @current_user = current_user
    @account = @current_user.account
    @options = options
    @content_type = options[:content_type]
    @ip_address_id = @options[:ip_address_id] unless %w[channel_feed newsmast].include?(@options[:channel_type])
    if @options[:id].present?
      update_community
    else
      create_community
    end
    create_content_type if @community.persisted?

    @community
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error("Community creation/update failed: #{e.message}")
    @community
  end

  def create_community
    ActiveRecord::Base.transaction do
      validate_collection
      validate_community_type
      validate_uniqueness(:slug)
      slug_uniqueness_within_accounts
      return @community if @community&.errors&.any?

      @community = Community.new(community_attributes)
      @community.save!
      set_default_additional_information
      assign_roles_and_content_type
      Rails.logger.info "IP Address ID: #{@ip_address_id}"
      IpAddress.find_by(id: @ip_address_id)&.increment_use_count! if @ip_address_id.present?
      @community
    end
    CommunityCreationJob.perform_later(@community.id, @current_user.id)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Community creation failed: #{e.message}")
    @community
  end

  def update_community
    ActiveRecord::Base.transaction do
      @community = Community.find_by(id: @options[:id])
      validate_collection
      validate_community_type
      return @community if @community&.errors&.any?
      set_default_additional_information
      @community.update(community_attributes)
      if @community.community_admins.present?
        @account = Account.find_by(id: @community.community_admins.first.account_id) if @current_user.master_admin?
        update_account_attributes
        update_community_admin
      end
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
    unless @options[:channel_type] == 'hub'
      if @options[:collection_id].blank?
        @community ||= Community.new()
        @community.errors.add(:collection_id, "could not be blank")
        return @community
      end

      @collection = Collection.find_by(id: @options[:collection_id])
      return handle_not_found('Collection') if @collection.nil?
    end
  end

  def validate_community_type
    @community_type = CommunityType.find_by(id: @options[:community_type_id])
    handle_not_found('Community Type') if @community_type.nil?
  end

  def validate_uniqueness(attribute)
    existing_community = Community.find_by(attribute => @options[attribute])
    if existing_community && existing_community.id != @options[:id].to_i
      @community ||= Community.new(community_attributes)
      @community.errors.add(attribute, "has already been taken")
      @community
    end
  end

  def slug_uniqueness_within_accounts
    return unless @options[:slug].present?

    if Account.where(username: @options[:slug].parameterize.underscore, domain: nil).exists?
      unless @current_user.user_admin? && @current_user&.account&.username == @options[:slug].parameterize.underscore
        @community ||= Community.new(community_attributes)
        @community.errors.add(:slug, "is already taken by an existing account username")
        @community
      end
    end
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

  def set_default_hashtag(community, user)
    return nil if community.nil? || user.nil?
    @community = community
    @current_user = user
    hashtag = "#{@community.slug.split('-').map(&:capitalize).join}Channel"
    community_id = @community.id

    CommunityHashtagPostService.new.call(hashtag: hashtag, community_id: community_id)

    ManageHashtagService.new(
      hashtag,
      :follow,
      ENV['MASTODON_INSTANCE_URL'],
      fetch_oauth_token(@current_user.id),
      community_id
    ).call
  end

  def fetch_oauth_token(user_id)
    token_service = GenerateAdminAccessTokenService.new(user_id)
    token_service.call
  end

  def assign_roles_and_content_type
    if @current_user.user_admin? || @current_user.hub_admin?
      update_account_attributes
      set_community_admin
      set_clean_up_policy
    end
  end

  def update_account_attributes
    p "START_UPDATING_ACCOUNT #{@community.slug.parameterize.underscore}"
    if @options[:id].present?
      @account.update!(
        display_name: @community.name,
        avatar: @community.avatar_image || '',
        header: @community.banner_image || '',
        note: @community.description || ''
      )
    else
      actor_type = @community.hub? ? "Application" : "Service"
      @account.update!(
        display_name: @community.name,
        username: @community.slug.parameterize.underscore,
        note: @community.description,
        avatar: @community.avatar_image || '',
        header: @community.banner_image || '',
        actor_type: actor_type,
        discoverable: true
      )
    end
  end

  def set_community_admin
    community_admin = CommunityAdmin.find_or_create_by(email: @current_user.email)

    community_admin.update(
      account_id: @account.id,
      patchwork_community_id: @community.id,
      username: @account.username,
      display_name: @community.name,
      role: @current_user&.role&.name,
      is_boost_bot: true
    )
  end

  def update_community_admin
    @community.community_admins.update(
      display_name: @community.name
    )
  end

  def create_content_type
    content_type = ContentType.find_or_initialize_by(patchwork_community_id: @community.id)
    content_type.update!(
      channel_type: @options[:content_type],
      custom_condition: custom_condition_value
    )
    boost_bot_account = Account.find_by(id: @community&.community_admins&.where(is_boost_bot: true)&.first&.account_id)
    if boost_bot_account
      if content_type.group_channel?
        boost_bot_account.update(locked: true)
      else
        boost_bot_account.update(locked: false)
      end
    end
  end

  def custom_condition_value
    case @content_type
    when 'custom_channel' then @community&.content_type&.custom_condition || 'or_condition'
    else nil
    end
  end

  def set_clean_up_policy
    policy = AccountStatusesCleanupPolicy.find_or_initialize_by(account_id: @account.id)
    policy.assign_attributes(enabled: true, min_status_age: 1.week.seconds)
    policy.save!
  end

  def community_attributes
    attributes = {
      name: @options[:name],
      description: @options[:bio],
      is_recommended: @options[:is_recommended],
      no_boost_channel: @options[:no_boost_channel],
      guides: nil,
      position: get_position,
      admin_following_count: 0,
      patchwork_community_type_id: @community_type.id,
      channel_type: @options[:channel_type],
      is_custom_domain: @options[:is_custom_domain],
      ip_address_id: @ip_address_id
    }

    if @options[:channel_type] == 'hub'
      attributes[:patchwork_collection_id] = nil
    else
      attributes[:patchwork_collection_id] = @collection.id
    end

    if @options[:id].blank? || (!@community&.visibility&.present? && !@current_user.user_admin?)
      attributes[:slug] = @options[:slug]
    end

    if @options[:logo_image].nil? && !@community&.logo_image.present?
      @community&.logo_image = nil
      @community&.logo_image_file_name = nil
    else
      attributes[:logo_image] = @options[:logo_image]
    end

    if @options[:avatar_image].nil? && !@community&.avatar_image.present?
      @community&.avatar_image = nil
      @community&.avatar_image_file_name = nil
    else
      attributes[:avatar_image] = @options[:avatar_image]
    end

    if @options[:banner_image].nil? && !@community&.banner_image.present?
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
