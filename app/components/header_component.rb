class HeaderComponent < ViewComponent::Base
  renders_one :brand
  renders_one :actions

  def initialize(title: nil)
    @title = title
  end

  private

  attr_reader :title
end