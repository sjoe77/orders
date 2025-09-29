class ManyToManyTabComponent < ViewComponent::Base
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  require 'ostruct'

  def initialize(parent:, relationship:, link_action_path:)
    @parent = parent
    @relationship = relationship.to_s
    @link_action_path = link_action_path
    @frame_id = "#{parent.class.name.downcase}_#{@relationship}"
    @title = @relationship.humanize
  end

  def call
    simple_modal + lazy_relationship_display
  end

  private

  attr_reader :parent, :relationship, :link_action_path, :frame_id, :title

  def relationship_class
    parent.class.reflect_on_association(relationship.to_sym)&.klass
  end

  def entity_name
    relationship.singularize
  end

  def current_items
    parent.send(relationship)
  end

  def current_items_paginated
    # Create a simple pagination result for current items using the actual PaginationResult class
    relation = current_items.limit(10).offset(0)

    # Create a simple pagination result for M:M relationships
    ManyToManyPaginationResult.new(
      records: relation.to_a,
      current_page: 1,
      per_page: 10,
      total_count: current_items.count
    )
  end

  # Simplified pagination result specifically for M:M relationship display
  class ManyToManyPaginationResult
    attr_reader :records, :current_page, :per_page, :total_count

    def initialize(records:, current_page:, per_page:, total_count:)
      @records = records
      @current_page = current_page
      @per_page = per_page
      @total_count = total_count
    end

    def total_pages
      (total_count.to_f / per_page).ceil
    end

    def offset_value
      (current_page - 1) * per_page
    end

    def limit_value
      per_page
    end

    def first?
      current_page == 1
    end

    def last?
      current_page >= total_pages
    end

    def prev_page
      return nil if first?
      current_page - 1
    end

    def next_page
      return nil if last?
      current_page + 1
    end

    def empty?
      records.empty?
    end
  end

  def available_items
    # Get all available items for linking (including currently linked ones for the modal)
    relationship_class.active
  end

  def available_items_paginated
    # Use proper pagination for the modal table
    Paginatable::PaginationResult.new(
      relation: available_items,
      page: 1, # TODO: Get from params for modal pagination
      per_page: 10
    )
  end

  def current_items_with_pending_changes
    # Show current relationships merged with any pending changes
    server_linked_ids = current_items.pluck(:id)
    pending_ids = extract_pending_relationship_ids

    base_relation = if pending_ids.present?
      # Show pending state instead of server state
      relationship_class.where(id: pending_ids)
    else
      current_items
    end

    # Return paginated results using the standard pagination system
    base_relation.paginated_results(relationship_params)
  end

  def extract_pending_relationship_ids
    # Extract M:M relationship changes from parent's pending_changes
    return [] unless parent.respond_to?(:pending_changes) && parent.pending_changes.present?

    begin
      pending_changes = JSON.parse(parent.pending_changes)
      pending_changes["#{relationship}_ids"] || []
    rescue JSON::ParserError
      []
    end
  end

  def table_config
    relationship_class.table_config.merge(
      entity_name: entity_name,
      frame_id: frame_id,
      show_delete_checkboxes: false
    )
  end

  def modal_table_config
    # Config for the modal table with checkboxes
    base_config = relationship_class.table_config.dup
    base_config.merge(
      entity_name: entity_name,
      frame_id: "#{frame_id}_modal",
      show_delete_checkboxes: false,
      show_checkboxes: true,
      checkbox_column: true
    )
  end

  def modal_id
    "#{entity_name}LinkModal_#{parent.class.name.downcase}_#{parent.id}"
  end

  def modal_path
    parent_entity = parent.class.name.downcase.pluralize
    "/#{parent_entity}/#{parent.id}/#{relationship}_modal"
  end

  def data_attributes
    {
      'many-to-many-relationship-type' => relationship,
      'many-to-many-relationship-pattern' => 'many_to_many',
      'many-to-many-link-action-path' => link_action_path,
      'many-to-many-frame-id' => frame_id
    }
  end

  def lazy_relationship_display
    helpers.turbo_frame_tag frame_id, src: relationship_path, loading: :lazy do
      loading_spinner
    end
  end

  def loading_spinner
    content_tag :div, class: "text-center py-3" do
      content_tag(:div, class: "spinner-border spinner-border-sm", role: "status") do
        content_tag(:span, "Loading...", class: "visually-hidden")
      end +
      content_tag(:div, "Loading #{title.downcase}...", class: "mt-2 text-muted")
    end
  end

  def relationship_path
    # Use Rails route helpers instead of manual string construction
    # This ensures proper turbo frame navigation
    parent_entity = parent.class.name.downcase
    helpers.send("#{relationship}_#{parent_entity}_path", parent)
  end

  def inline_relationship_display
    helpers.turbo_frame_tag frame_id do
      content_tag :div, class: "relationship-section" do
        relationship_header + relationship_table
      end
    end
  end


  def relationship_header
    # Get the paginated result to show accurate count and pagination info
    paginated_items = current_items_with_pending_changes
    total_count = paginated_items.respond_to?(:total_count) ? paginated_items.total_count : current_items.count

    content_tag :div, class: "d-flex justify-content-between align-items-center mb-3" do
      content_tag(:h6, "#{title} (#{total_count})", class: "mb-0") +
      manage_button
    end
  end

  def manage_button
    content_tag :button,
                type: "button",
                class: "btn btn-primary btn-sm",
                data: {
                  bs_toggle: "modal",
                  bs_target: "##{modal_id}"
                } do
      content_tag(:i, '', class: "bi bi-link") + " Manage #{title}"
    end
  end

  def relationship_table
    displayed_items = current_items_with_pending_changes

    if !displayed_items.empty?
      table_content = helpers.render TableComponent.new(
        collection: displayed_items,
        config: table_config,
        current_params: relationship_params
      )

      pending_changes_notice = if extract_pending_relationship_ids.present?
        content_tag :div, class: "alert alert-info alert-sm mt-2 mb-0" do
          content_tag(:i, '', class: "bi bi-info-circle me-1") +
          content_tag(:small, "Changes pending - submit form to save")
        end
      else
        ""
      end

      table_content + pending_changes_notice
    else
      content_tag :div, class: "text-center py-4 text-muted" do
        content_tag(:i, '', class: "bi bi-link-45deg fs-1 mb-2 d-block") +
        content_tag(:p, "No #{title.downcase} linked yet", class: "mb-0") +
        content_tag(:small, "Click \"Manage #{title}\" to add relationships")
      end
    end
  end

  def build_relationship_table(items)
    content_tag :div, class: "table-container" do
      content_tag :div, class: "table-responsive" do
        content_tag :table, class: "table table-striped table-hover" do
          relationship_table_header + relationship_table_body(items)
        end
      end
    end
  end

  def relationship_table_header
    content_tag :thead, class: "table-secondary" do
      content_tag :tr do
        relationship_column_headers
      end
    end
  end

  def relationship_column_headers
    columns = relationship_class.table_config[:columns] || {}
    columns.map do |field, config|
      content_tag :th, class: column_alignment_class(config[:format]) do
        I18n.t("attributes.#{entity_name}.#{field}")
      end
    end.join.html_safe
  end

  def relationship_table_body(items)
    content_tag :tbody do
      items.map do |item|
        content_tag :tr, style: "cursor: default;" do
          relationship_data_cells(item)
        end
      end.join.html_safe
    end
  end

  def relationship_data_cells(item)
    columns = relationship_class.table_config[:columns] || {}
    columns.map do |field, config|
      content_tag :td, class: column_alignment_class(config[:format]) do
        format_table_value(item.public_send(field), config[:format], config)
      end
    end.join.html_safe
  end

  def simple_modal
    content_tag :div,
                class: "modal fade",
                id: modal_id,
                tabindex: "-1",
                aria: { hidden: "true" },
                data: { "bs-backdrop" => "true", "bs-keyboard" => "true" },
                style: "display: none; z-index: 1090;" do
      content_tag :div, class: "modal-dialog modal-lg" do
        content_tag :div, class: "modal-content" do
          simple_modal_header + simple_modal_body + simple_modal_footer
        end
      end
    end
  end

  def simple_modal_header
    content_tag :div, class: "modal-header" do
      content_tag(:h5, "Manage #{title} for #{parent.class.name}", class: "modal-title") +
      content_tag(:button, "",
                  type: "button",
                  class: "btn-close",
                  data: { bs_dismiss: "modal" },
                  aria: { label: "Close" })
    end
  end

  def simple_modal_body
    content_tag :div, class: "modal-body" do
      helpers.turbo_frame_tag "#{frame_id}_modal", src: modal_path do
        content_tag(:div, "Loading #{relationship}...", class: "text-center py-3")
      end
    end
  end


  def simple_modal_footer
    content_tag :div, class: "modal-footer" do
      content_tag(:button, "Close",
                  type: "button",
                  class: "btn btn-secondary",
                  data: { bs_dismiss: "modal" })
    end
  end

  def column_alignment_class(format_type)
    case format_type
    when 'integer', 'decimal', 'currency'
      'text-end'
    when 'boolean'
      'text-center'
    else
      'text-start'
    end
  end

  def format_table_value(value, format_type, config = {})
    case format_type
    when 'boolean'
      if value
        content_tag(:i, '', class: "bi-check-circle-fill text-success", title: I18n.t("common.yes", default: "Yes"))
      else
        content_tag(:i, '', class: "bi-x-circle-fill text-danger", title: I18n.t("common.no", default: "No"))
      end
    when 'currency'
      number_to_currency(value || 0)
    when 'integer'
      value.to_i
    else
      value.to_s
    end
  end

  def relationship_params
    # Extract only the parameters relevant to this relationship
    # This isolates sorting/filtering from other tabs
    all_params = helpers.params.permit!

    # Filter to only include parameters relevant to this relationship
    relationship_specific_params = all_params.select do |key, value|
      key.to_s.in?(['sort', 'direction', 'page', 'per_page', 'search']) ||
      key.to_s.starts_with?('filter_')
    end

    # Return as a regular hash
    relationship_specific_params.to_h
  end
end