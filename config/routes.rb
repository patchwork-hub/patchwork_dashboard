require 'sidekiq/web'
require 'sidekiq-scheduler'

Rails.application.routes.draw do
  authenticate :user, lambda { |u| u.master_admin? } do
    mount Sidekiq::Web, at: 'sidekiq', as: :sidekiq
  end

  root 'homepage#index'

  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }

  health_check_routes

  resources :follows

  resources :communities, path: 'channels' do
    collection do
      get 'step0', to: 'communities#step0', as: 'step0_new'
      post 'step0', to: 'communities#step0_save'
      get 'step1', to: 'communities#step1', as: 'step1_new'
      post 'step1', to: 'communities#step1_save'
    end
    member do
      get 'step2', to: 'communities#step2'
      get 'step3', to: 'communities#step3'
      get 'step4', to: 'communities#step4'
      get 'step5', to: 'communities#step5'
      get 'step6', to: 'communities#step6'
      get 'search_contributor', to: 'communities#search_contributor'
      post 'mute_contributor', to: 'communities#mute_contributor'
      post 'unmute_contributor', to: 'communities#unmute_contributor'
      post 'set_visibility', to: 'communities#set_visibility'
      post 'manage_additional_information', to: 'communities#manage_additional_information'
      get 'follower_list', to: 'communities#follower_list'
      get 'follower_list_csv', to: 'communities#follower_list_csv'
      post 'recover', to: 'communities#recover'
      post 'upgrade', to: 'communities#upgrade'
    end
    resources :community_hashtags, only: %i[create update destroy]
    resource :community_post_type, only: [:create, :update]
    resources :post_hashtags, only: [:create, :update, :destroy]
  end

  get '/domain/verify', to: 'domains#verify'

  resources :community_admins

  resources :community_filter_keywords, only: [:index, :create, :update, :destroy]

  resources :community do
    resources :hashtag
  end

  resources :accounts do
    member do
      post 'follow'
      post 'unfollow'
    end
    collection do
      match :export, via: [:get, :post]
    end
  end

  resources :server_settings do
    collection do
      get :group_data
    end
  end

  get '/homepage', to: 'homepage#index'
  get '/installation', to: 'installation#index'
  get '/resources', to: 'resources#index'

  resources :keyword_filter_groups do
    member do
      patch :update_is_active
    end
    resources :keyword_filters
  end

  resources :api_keys, path: 'api-key'

  draw :api_v1

  resources :collections

  resources :content_types, only: [:create]

  resources :community_admins, except: [:show, :index]

  resources :master_admins, except: [:show, :destroy]

  resources :wait_lists

  resources :app_versions
  patch "history/:id/deprecate", to: 'app_versions#deprecate'
end
