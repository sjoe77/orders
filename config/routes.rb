Rails.application.routes.draw do
  resources :customers
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Main navigation routes
  root "home#index"
  
  # Template navigation routes (for demonstration)
  get "products", to: "home#products"
  get "customers", to: "customers#index" 
  get "orders", to: "home#orders"
  get "reports", to: "home#reports"
  get "settings", to: "home#settings"
  
  # Keep original route for compatibility
  get "home/index"
end
