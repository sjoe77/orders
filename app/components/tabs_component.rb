class TabsComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  renders_many :tabs, "TabComponent"

  def initialize(id: nil, **options)
    @id = id || "tabs_#{SecureRandom.hex(4)}"
    @options = options
  end

  private

  attr_reader :id, :options

  class TabComponent < ViewComponent::Base
    def initialize(title:, id: nil, active: false, **options)
      @title = title
      @id = id || "tab_#{SecureRandom.hex(4)}"
      @active = active
      @options = options
    end

    def call
      content
    end

    attr_reader :title, :id, :active, :options

    def tab_id
      "#{id}_tab"
    end

    def pane_id
      "#{id}_pane"
    end

    def nav_classes
      classes = ['nav-link']
      classes << 'active' if active
      classes.join(' ')
    end

    def pane_classes
      classes = ['tab-pane', 'fade']
      classes << 'show active' if active
      classes.join(' ')
    end
  end
end