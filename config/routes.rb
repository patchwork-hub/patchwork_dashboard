Rails.application.routes.draw do

  authenticate :user, lambda { |u| u.owner? } do
    mount Sidekiq::Web, at: 'sidekiq', as: :sidekiq
  end

  root 'homepage#index'

  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }

  health_check_routes

  resources :wait_lists, only: %i[ index show create ]
  get '/invitation_codes', to: 'wait_lists#invitation_codes', as: :invitation_codes
  get 'invitation_code_list', to: 'wait_lists#invitation_code_list', as: :invitation_code_list
  get '/invitation_codes/:id', to: 'wait_lists#invitation_code', as: :invitation_code
  match '/invitation_codes/export/new', to: 'wait_lists#export', as: :export_invitation_codes, via: [:get, :post]

  resources :follows

  resources :communities do
    collection do
      get 'step1', to: 'communities#step1', as: 'step1_new'
      post 'step1', to: 'communities#step1_save'
    end
    member do
      get 'step2', to: 'communities#step2'
      post 'step2', to: 'communities#step2_save'
      get 'step3', to: 'communities#step3'
      get 'contributors_table', to: 'communities#contributors_table'
      post 'step3', to: 'communities#step3_save'
      get 'step4', to: 'communities#step4'
      post 'step4', to: 'communities#step4_save'
      post 'step5_update', to: 'communities#step5_update'
      post 'step5_delete', to: 'communities#step5_delete'
      get 'step5', to: 'communities#step5'
      post 'step5', to: 'communities#step5_save'
      get 'step6', to: 'communities#step6'
      post 'step6', to: 'communities#step6_save'
      post 'step6_rule_create', to: 'communities#step6_rule_create'
      get 'search_contributor', to: 'communities#search_contributor'
      post 'mute_contributor', to: 'communities#mute_contributor'
      post 'unmute_contributor', to: 'communities#unmute_contributor'
      get 'is_muted', to: 'communities#is_muted'
      post 'set_visibility', to: 'communities#set_visibility'
      post 'manage_additional_information', to: 'communities#manage_additional_information'
    end
  end  

  resources :community_admins

  resources :community_filter_keywords, only: [:create, :update, :destroy]

  resources :community do
    resources :hashtag
  end
  resources :reports, only: %i[ index show ]
  resources :accounts do
    member do
      post 'follow'
      post 'unfollow'
    end
    collection do
      match :export, via: [:get, :post]
    end
  end

  resources :app_versions
  put "history/:id/deprecate", to: 'app_versions#deprecate'
  resources :global_filters
  get '/timelines_status', to: 'timelines_status#index'

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
end
