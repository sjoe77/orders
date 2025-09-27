class NavigationComponent < ViewComponent::Base
  renders_many :menu_items

  def initialize(menu_items: [])
    @menu_items_data = menu_items
  end

  private

  attr_reader :menu_items_data

  def default_menu_items
    # Check for application-configured menu items first
    if Rails.application.config.respond_to?(:navigation_menu_items)
      Rails.application.config.navigation_menu_items
    else
      # Fallback template menu items for demonstration
      [
        { path: "/", label: "Home", icon: "house", active: helpers.current_page?("/") },
        { path: "/orders", label: "Orders", icon: "receipt", active: helpers.current_page?("/orders") },
        { path: "/customers", label: "Customers", icon: "people", active: helpers.current_page?("/customers") },
        { path: "/products", label: "Products", icon: "box", active: helpers.current_page?("/products") },
        { divider: true },
        { path: "/settings", label: "Settings", icon: "gear", active: helpers.current_page?("/settings") },
        { path: "/help", label: "Help", icon: "question-circle", active: helpers.current_page?("/help") }
      ]
    end
  end

  def menu_items_to_render
    menu_items_data.any? ? menu_items_data : default_menu_items
  end
end