class AppShellComponent < ViewComponent::Base
  renders_one :header
  renders_one :navigation
  renders_one :main_content

  def initialize(drawer_open: false)
    @drawer_open = drawer_open
  end

  private

  attr_reader :drawer_open

  def drawer_class
    drawer_open ? "drawer-open" : ""
  end
end