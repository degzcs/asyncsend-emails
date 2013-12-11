SendEmails::Application.routes.draw do

  devise_for :users
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  root :to => "users#index"

  resources :users
  # CSV Imports
  resources :user_imports, only: [:new, :create]

  #mandrill
    match 'webhook' => 'mandrill#webhook', as: :mandrill_webhook
    post 'send_user_email' => 'mandrill#send_user_email', as: :mandrill_send_user_email
    resource :mandrill
end
