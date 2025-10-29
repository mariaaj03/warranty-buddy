Rails.application.routes.draw do
  root "dashboard#index"

  # OAuth callback & failure
  get '/auth/:provider/callback', to: 'dashboard#google_auth'
  get '/auth/failure', to: 'dashboard#oauth_failure'

  #csv/ical routes
  resources :products, only: [] do
    collection { get :export }  # /products/export.csv
  end

  resources :products, only: [] do
    collection do
      get :export                  # CSV
      get :calendar, defaults: { format: :ics }  # iCal
    end
  end

  

  # Dashboard routes
  get "dashboard/index"
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
end
