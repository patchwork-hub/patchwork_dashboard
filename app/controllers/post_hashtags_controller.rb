# app/controllers/post_hashtags_controller.rb
class PostHashtagsController < ApplicationController
  before_action :set_community
  before_action :set_post_hashtag, only: [:update, :destroy]

  def create
    authorize @community, :step3?
    PostHashtagService.new.call(post_hashtag_params)
    flash[:notice] = "Post hashtag saved successfully!"
    redirect_to step3_community_path(@community)
  rescue ActiveRecord::RecordNotUnique
    flash[:error] = "Duplicate entry: Post hashtag already exists."
    redirect_to step3_community_path(@community)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.join(", ")
    redirect_to step3_community_path(@community)
  end

  def update
    authorize @community, :step3?
    @post_hashtag.update!(hashtag: params[:form_post_hashtag][:hashtag]&.gsub('#', ''))
    flash[:notice] = "Post hashtag updated successfully!"
    redirect_to step3_community_path(@community)
  rescue ActiveRecord::RecordNotUnique
    flash[:error] = "Duplicate entry: Post hashtag already exists."
    redirect_to step3_community_path(@community)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.join(", ")
    redirect_to step3_community_path(@community)
  end

  def destroy
    authorize @community, :step3?
    if @post_hashtag.destroy
      flash[:notice] = "Post hashtag removed successfully!"
    else
      flash[:error] = "Failed to remove post hashtag."
    end
    redirect_to step3_community_path(@community)
  end

  private

  def set_community
    @community = Community.find(params[:community_id])
  end

  def set_post_hashtag
    @post_hashtag = PostHashtag.find(params[:id])
  end

  def post_hashtag_params
    params.require(:form_post_hashtag).permit(:community_id, :hashtag)
  end
end
