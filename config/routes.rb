Rails.application.routes.draw do
  root "home#index"
  
  # Devise routes
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }
  
  # Wrap the OAuth failure route in devise_scope
  devise_scope :user do
    get "/users/auth/failure", to: "users/omniauth_callbacks#failure"
  end
  
  # Dashboard routes (require authentication)
  get "dashboard", to: "dashboard#index", as: :dashboard

  # csv/ical routes
  resources :products, only: [] do
    collection { get :export }  # /products/export.csv
  end

  resources :products, only: [] do
    collection do
      get :export                  # CSV
      get :calendar, defaults: { format: :ics }  # iCal
      post :export_to_google_calendar  # Google Calendar
    end
  end



  # Dashboard routes (require authentication)
  get "dashboard/connect_gmail"
  get "dashboard/upload"
  post "/upload", to: "dashboard#upload"
  get "dashboard/api_warranties"
  get "dashboard/api_health"
  get "dashboard/reset"
  post "/disconnect_gmail", to: "dashboard#disconnect_gmail"
  post "/parse_gmail_receipts", to: "dashboard#parse_gmail_receipts"
  post "/check_warranty_eligibility", to: "dashboard#check_warranty_eligibility"
  get "/lookup_warranty_info", to: "dashboard#lookup_warranty_info"
  delete "/warranties/:id", to: "dashboard#delete_warranty", as: :delete_warranty
  patch "/warranties/:id", to: "dashboard#update_warranty", as: :update_warranty
  patch '/update_warranty/:id', to: 'dashboard#update_warranty'
  
  post "/chatbot/ask", to: "chatbot#ask", as: :chatbot_ask
end
