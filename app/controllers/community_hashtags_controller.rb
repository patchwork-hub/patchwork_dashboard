class CommunityHashtagsController < BaseController
  before_action :authenticate_user!
  before_action :set_community
  before_action :set_api_credentials
  before_action :set_hashtag, only: [:update, :destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from CommunityHashtagPostService::InvalidHashtagError, with: :handle_invalid_hashtag

  def create
    hashtag = parsed_hashtag_param
    CommunityHashtag.transaction do
      @community_hashtag = @community.patchwork_community_hashtags.create!(hashtag: hashtag, name: hashtag)
      perform_hashtag_action(hashtag, :follow)
    end
    handle_success("Hashtag saved successfully!")
  rescue ActiveRecord::RecordNotUnique
    handle_error("Duplicate entry: Hashtag already exists.")
  end

  def update
    CommunityHashtag.transaction do
      perform_hashtag_action(@hashtag.hashtag, :unfollow)
      @hashtag.update!(hashtag: parsed_hashtag_param, name: parsed_hashtag_param)
      perform_hashtag_action(parsed_hashtag_param, :follow)
    end
    handle_success("Hashtag updated successfully!")
  end

  def destroy
    CommunityHashtag.transaction do
      perform_hashtag_action(@hashtag.hashtag, :unfollow)
      @hashtag.destroy!
    end
    handle_success("Hashtag removed successfully!")
  end

  private

  def set_community
    @community = Community.find(params[:community_id])
  end

  def set_hashtag
    @hashtag = @community.patchwork_community_hashtags.find(params[:id])
  end

  def community_hashtag_params
    params.require(:form_community_hashtag).permit(:hashtag, :hashtag_id)
  end

  def parsed_hashtag_param
    community_hashtag_params[:hashtag].to_s.gsub('#', '')
  end

  def perform_hashtag_action(hashtag_name, action)
    validate_and_search_hashtag(hashtag_name)
    execute_hashtag_service(action, hashtag_name)
    perform_relay_action(hashtag_name, action)
  end

  def validate_and_search_hashtag(hashtag_name)
    hashtag = SearchHashtagService.new(@api_base_url, @token, hashtag_name).call
    return if hashtag

    raise CommunityHashtagPostService::InvalidHashtagError, "Invalid hashtag: ##{hashtag_name}"
  end

  def execute_hashtag_service(action, hashtag_name)
    service_class = action == :follow ? FollowHashtagService : UnfollowHashtagService
    service_class.new(@api_base_url, @token, hashtag_name).call
  end

  def perform_relay_action(hashtag_name, action)
    token = fetch_owner_token
    action == :follow ? create_relay(hashtag_name, token) : delete_relay(hashtag_name, token)
  end

  def fetch_owner_token
    owner_user = User.find_by!(role: UserRole.find_by(name: 'Owner'))
    fetch_oauth_token(owner_user.id)
  end

  def create_relay(hashtag_name, token)
    inbox_url = "https://relay.fedi.buzz/tag/#{hashtag_name}"
    CreateRelayService.new(@api_base_url, token, hashtag_name).call unless Relay.exists?(inbox_url: inbox_url)
  end

  def delete_relay(hashtag_name, token)
    inbox_url = "https://relay.fedi.buzz/tag/#{hashtag_name}"
    if (relay = Relay.find_by(inbox_url: inbox_url)) && !other_communities_using_hashtag?(hashtag_name)
      DeleteRelayService.new(@api_base_url, token, relay.id).call
    end
  end

  def other_communities_using_hashtag?(hashtag_name)
    CommunityHashtag.where(name: hashtag_name).where.not(patchwork_community_id: @community.id).exists?
  end

  def handle_success(message)
    flash[:notice] = message
    redirect_to step3_community_path(@community)
  end

  def handle_error(message)
    flash[:error] = message
    redirect_to step3_community_path(@community)
  end

  def handle_record_not_found
    handle_error("The requested resource could not be found")
  end

  def handle_invalid_hashtag(exception)
    handle_error(exception.message)
  end
end
