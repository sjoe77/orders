class PageHeaderComponent < ViewComponent::Base
  renders_one :title
  renders_one :actions

  def initialize(sticky: true, **options)
    @sticky = sticky
    @options = options
  end

  private

  attr_reader :sticky, :options

  def header_classes
    classes = ['page-header', 'bg-white', 'border-bottom', 'py-3', 'px-3']
    if sticky
      classes << 'position-sticky'
      classes << 'top-0'
      classes << 'z-3'
    end
    classes << options[:class] if options[:class]
    classes.join(' ')
  end

  def container_classes
    ['d-flex', 'justify-content-between', 'align-items-center'].join(' ')
  end
end