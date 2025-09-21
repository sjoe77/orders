class PageHeaderComponent < ViewComponent::Base
  renders_one :title
  renders_one :actions

  def initialize(sticky: true, auto_detect: true, record: nil, **options)
    @sticky = sticky
    @auto_detect = auto_detect
    @record = record
    @options = options
  end

  private

  attr_reader :sticky, :auto_detect, :record, :options

  def current_record
    return record if record.present?
    return nil unless auto_detect

    controller_name = helpers.controller.controller_name.singularize
    helpers.instance_variable_get("@#{controller_name}")
  rescue
    nil
  end

  def entity_name
    return nil unless current_record
    current_record.class.model_name.human
  end

  def page_title
    return nil unless current_record

    if current_record.persisted?
      base_title = t('page_titles.edit', entity: entity_name, default: "Edit #{entity_name}")
      identifier = record_identifier
      identifier.present? ? "#{base_title} #{identifier}" : base_title
    else
      t('page_titles.new', entity: entity_name, default: "New #{entity_name}")
    end
  end

  def record_identifier
    return nil unless current_record&.persisted?

    # Try common identifier patterns
    %w[num number key code id].each do |suffix|
      attr_name = "#{current_record.class.model_name.singular}_#{suffix}_nm"
      if current_record.respond_to?(attr_name)
        value = current_record.public_send(attr_name)
        return "##{value}" if value.present?
      end
    end

    # Fallback to ID
    "##{current_record.id}"
  end

  def show_default_actions?
    auto_detect && current_record.present?
  end

  def form_id
    return nil unless current_record
    "#{current_record.class.model_name.singular}_form"
  end

  def entity_path
    return nil unless current_record
    helpers.url_for(controller: helpers.controller.controller_name, action: :index)
  end

  def reason_key
    @reason_key ||= SecureRandom.uuid
  end

  def header_classes
    classes = ['page-header', 'bg-white', 'border-bottom', 'py-3', 'px-3']
    if sticky
      classes << 'position-sticky'
      classes << 'top-0'
      classes << 'sticky-top'
    end
    classes << options[:class] if options[:class]
    classes.join(' ')
  end

  def container_classes
    ['d-flex', 'justify-content-between', 'align-items-center'].join(' ')
  end
end