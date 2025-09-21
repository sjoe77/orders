class RelationshipModalComponent < ViewComponent::Base
  def initialize(modal_id:, title:, form_partial:, **options)
    @modal_id = modal_id
    @title = title
    @form_partial = form_partial
    @options = options
  end

  private

  attr_reader :modal_id, :title, :form_partial, :options

  def modal_size
    options.fetch(:size, 'modal-lg')
  end

  def show_footer?
    options.fetch(:show_footer, true)
  end

  def cancel_label
    options.fetch(:cancel_label, 'Cancel')
  end

  def submit_label
    options.fetch(:submit_label, 'Save')
  end
end