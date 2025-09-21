class ModalDialogManagerComponent < ViewComponent::Base
  renders_one :body
  renders_one :footer

  def initialize(id:, title:, size: 'md', backdrop: true, keyboard: true, **options)
    @id = id
    @title = title
    @size = size
    @backdrop = backdrop
    @keyboard = keyboard
    @options = options
  end

  private

  attr_reader :id, :title, :size, :backdrop, :keyboard, :options

  def modal_classes
    classes = ['modal', 'fade']
    classes << options[:class] if options[:class]
    classes.join(' ')
  end

  def dialog_classes
    classes = ['modal-dialog']
    classes << "modal-#{size}" unless size == 'md'
    classes << 'modal-dialog-centered' if options[:centered]
    classes << 'modal-dialog-scrollable' if options[:scrollable]
    classes.join(' ')
  end

  def modal_attributes
    attrs = {
      id: id,
      class: modal_classes,
      tabindex: -1,
      'aria-labelledby': "#{id}Label",
      'aria-hidden': true
    }

    attrs['data-bs-backdrop'] = backdrop.to_s
    attrs['data-bs-keyboard'] = keyboard.to_s
    attrs['data-controller'] = 'modal-dialog'

    attrs
  end

  def has_custom_footer?
    footer?
  end

  def show_default_footer?
    !has_custom_footer? && !options[:hide_footer]
  end

  def cancel_button_text
    options[:cancel_text] || 'Cancel'
  end

  def save_button_text
    options[:save_text] || 'Save'
  end

  def save_button_variant
    options[:save_variant] || 'primary'
  end
end