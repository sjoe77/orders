# Navigation Configuration for Rails Application Template
#
# This initializer allows applications to configure their navigation menu items
# without hardcoding them in the NavigationComponent. This keeps the component
# generic and reusable across different applications.
#
# To customize navigation for your application, modify the menu items below
# or set Rails.application.config.navigation_menu_items in your environment files.

Rails.application.configure do
  # Define navigation menu items for this application
  # Each item should have: path, label, icon (Bootstrap Icons class name)
  # Use { divider: true } for menu separators
  config.navigation_menu_items = [
    { path: "/", label: "Home", icon: "house" },
    { path: "/orders", label: "Orders", icon: "receipt" },
    { path: "/customers", label: "Customers", icon: "people" },
    { path: "/products", label: "Products", icon: "box" },
    { divider: true },
    { path: "/settings", label: "Settings", icon: "gear" },
    { path: "/help", label: "Help", icon: "question-circle" }
  ]

  # Note: The NavigationComponent will automatically set the 'active' state
  # based on the current page path, so you don't need to specify it here.
end