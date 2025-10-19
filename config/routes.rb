Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  root to: proc { [200, { 'Content-Type' => 'text/plain' }, ['Hello! New Rails app is working!']] }

  # Defines the root path route ("/")
  # root "posts#index"
  post "/signup", to: "users#signup"
  get "/users", to: "users#index"
  put "/activate", to: "users#activate"
  # Local failure page to render activation errors with a message
  get "/activation/failure", to: "users#activation_failure", as: :activation_failure
  post "/resend_activation", to: "users#resend_activation"
  post "/login", to: "sessions#create"
  post "/refresh", to: "sessions#refresh"
  post "/logout", to: "sessions#destroy"
  post "/password/forgot", to: "passwords#create"
  put "/password/reset", to: "passwords#update"
  resources :tasks
  resources :settings, only: [:index, :create, :update, :destroy]
  get '/health', to: 'health#check'

end


