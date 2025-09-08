class CommunityHashtagsController < BaseController
  before_action :authenticate_user!
  before_action :set_community
  before_action :set_api_credentials
  before_action :set_hashtag, only: [:update, :destroy]

  def create
    begin
      perform_hashtag_action(community_hashtag_params[:hashtag].gsub('#', ''), community_hashtag_params[:community_id], :follow)
      flash[:notice] = "Hashtag saved successfully!"
    rescue CommunityHashtagPostService::InvalidHashtagError => e
      flash[:error] = e.message
    rescue ActiveRecord::RecordNotUnique => e
      flash[:error] = "Duplicate entry: Hashtag already exists."
    end

    redirect_to step3_community_path(@community)
  end

  def update
    begin
      community_hashtag = CommunityHashtag.find(params[:id])
      old_hashtag = community_hashtag.hashtag
      form_community_hashtag_params = params.require(:form_community_hashtag).permit(:hashtag)
      new_hashtag = form_community_hashtag_params[:hashtag].gsub('#', '')
  
      if old_hashtag != new_hashtag
        perform_hashtag_action(old_hashtag, params[:community_id], :unfollow)
        community_hashtag.assign_attributes(hashtag: new_hashtag, name: new_hashtag)
        community_hashtag.save!
        perform_hashtag_action(new_hashtag, nil, :follow)
      end
  
      flash[:notice] = "Hashtag updated successfully!"
    rescue CommunityHashtagPostService::InvalidHashtagError => e
      flash[:error] = e.message
    rescue ActiveRecord::RecordNotUnique => e
      flash[:error] = "Duplicate entry: Hashtag already exists."
    end

    redirect_to step3_community_path(@community)
  end

  def destroy
    hashtag = CommunityHashtag.find(params[:id])
    community_id = hashtag.patchwork_community_id

    if hashtag.destroy
      perform_hashtag_action(hashtag.hashtag, community_id, :unfollow)
      flash[:notice] = "Hashtag removed successfully!"
    else
      flash[:error] = "Failed to remove hashtag."
    end
    redirect_to step3_community_path(@community)
  end

  private

  def set_community
    @community = Community.find(params[:community_id])
  end

  def set_hashtag
    @hashtag = @community.patchwork_community_hashtags.find(params[:id])
  end

  def community_hashtag_params
    params.require(:form_community_hashtag).permit(:hashtag, :community_id)
  end

  def perform_hashtag_action(hashtag_name, community_id = nil, action)
    if action == :follow && community_id
      CommunityHashtagPostService.new.call(hashtag: hashtag_name, community_id: community_id)
    end

    hashtag = SearchHashtagService.new(@api_base_url, @token, hashtag_name).call
    return puts "Hashtag not found" unless hashtag

    service_class = action == :follow ? FollowHashtagService : UnfollowHashtagService
    result = service_class.new(@api_base_url, @token, hashtag[:name]).call
    puts result ? "Successfully #{action}ed ##{hashtag[:name]}" : "Failed to #{action} ##{hashtag[:name]}"

    perform_relay_action(hashtag_name, community_id, action)
  end

  def perform_relay_action(hashtag_name, community_id, action)
    owner_role = UserRole.find_by(name: 'Owner')
    owner_user = User.find_by(role: owner_role)
    token = fetch_oauth_token(owner_user.id)

    if action == :follow
      create_relay(hashtag_name, token)
    end

    if action == :unfollow
      unless CommunityHashtag.where(name: hashtag_name).where.not(patchwork_community_id: community_id).exists?
        delete_relay(hashtag_name, token)
      end
    end
  end

  def create_relay(hashtag_name, token)
    inbox_url = "https://relay.fedi.buzz/tag/#{hashtag_name}"
    unless Relay.exists?(inbox_url: inbox_url)
      CreateRelayService.new(@api_base_url, token, hashtag_name).call
    end
  end

  def delete_relay(hashtag_name, token)
    inbox_url = "https://relay.fedi.buzz/tag/#{hashtag_name}"
    relay = Relay.find_by(inbox_url: inbox_url)
    if relay
      DeleteRelayService.new(@api_base_url, token, relay.id).call
    end
  end
end
