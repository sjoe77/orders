class RelationshipTabComponent < ViewComponent::Base
  include ActionView::Helpers::UrlHelper

  def initialize(parent:, relationship:, pattern:, default: false, title: nil)
    @parent = parent
    @relationship = relationship.to_s
    @pattern = pattern.to_sym
    @default = default
    @title = title || default_title
    @frame_id = "#{parent.class.name.downcase}_#{@relationship}"
  end

  private

  attr_reader :parent, :relationship, :pattern, :default, :title, :frame_id

  def default_title
    parent_entity = parent.class.name.downcase.pluralize
    I18n.t("#{parent_entity}.tabs.#{relationship}", default: relationship.humanize)
  end

  def relationship_path
    case pattern
    when :nested_attributes, :independent_save
      # For 1:M relationships: /parents/123/children
      helpers.send("#{parent.class.name.downcase}_#{relationship}_path", parent)
    when :many_to_many
      # For M:M relationships: /parents/123/related_items
      helpers.send("#{parent.class.name.downcase}_#{relationship}_path", parent)
    end
  end

  def relationship_class
    # Get the model class for this relationship
    parent.class.reflect_on_association(relationship.to_sym)&.klass
  end

  def entity_name
    relationship.singularize
  end

  def data_attributes
    {
      'relationship-type' => relationship,
      'relationship-pattern' => pattern.to_s
    }
  end

  def loading_spinner
    content_tag :div, class: "text-center py-3" do
      content_tag(:div, class: "spinner-border spinner-border-sm", role: "status") do
        content_tag(:span, "Loading...", class: "visually-hidden")
      end +
      content_tag(:div, "Loading #{title.downcase}...", class: "mt-2 text-muted")
    end
  end

  def tab_content
    if default
      # Default tab renders immediately with server-side data
      render_relationship_content
    else
      # Non-default tabs use lazy loading
      helpers.turbo_frame_tag frame_id, src: relationship_path, loading: :lazy do
        loading_spinner
      end
    end
  end

  def render_relationship_content
    # For default tab, render the relationship content directly
    case pattern
    when :nested_attributes, :independent_save
      render_one_to_many_content
    when :many_to_many
      render_many_to_many_content
    end
  end

  def render_one_to_many_content
    helpers.turbo_frame_tag frame_id do
      content_tag :div, class: "relationship-section", data: data_attributes do
        relationship_header + relationship_table + add_edit_modals
      end
    end
  end

  def render_many_to_many_content
    helpers.turbo_frame_tag frame_id do
      content_tag :div, class: "relationship-section", data: data_attributes do
        relationship_header + relationship_table + link_unlink_controls
      end
    end
  end

  def relationship_header
    content_tag :div, class: "d-flex justify-content-between align-items-center mb-3" do
      content_tag(:h6, title, class: "mb-0") +
      header_actions
    end
  end

  def header_actions
    content_tag :div, class: "d-flex gap-2" do
      case pattern
      when :nested_attributes
        add_button + delete_selected_button
      when :independent_save
        add_button
      when :many_to_many
        link_button
      end
    end
  end

  def add_button
    content_tag :button, class: "btn btn-primary btn-sm",
                data: {
                  bs_toggle: "modal",
                  bs_target: "##{entity_name}AddModal"
                } do
      content_tag(:i, '', class: "bi bi-plus-circle") + " " +
      I18n.t("actions.add_#{entity_name}", default: "Add #{entity_name.humanize}")
    end
  end

  def delete_selected_button
    content_tag :button,
                class: "btn btn-outline-danger btn-sm",
                id: "delete-selected-#{relationship}",
                disabled: true,
                data: {
                  controller: "relationship-delete",
                  relationship_delete_relationship_value: relationship,
                  relationship_delete_entity_value: entity_name
                } do
      content_tag(:i, '', class: "bi bi-trash") + " " +
      I18n.t("actions.delete_selected", default: "Delete Selected")
    end
  end

  def link_button
    content_tag :button, class: "btn btn-primary btn-sm",
                data: {
                  bs_toggle: "modal",
                  bs_target: "##{entity_name}LinkModal"
                } do
      content_tag(:i, '', class: "bi bi-link") + " " +
      I18n.t("actions.link_#{entity_name}", default: "Link #{entity_name.humanize}")
    end
  end

  def relationship_table
    # Get the collection data for this relationship
    collection = get_relationship_collection
    return content_tag(:p, "No #{title.downcase} found", class: "text-muted") if collection.empty?

    # Get the table config from the relationship model
    config = relationship_class.table_config.merge(
      entity_name: entity_name,
      base_url: relationship_path,
      frame_id: frame_id,
      show_delete_checkboxes: (pattern == :nested_attributes),
      delete_checkbox_name: "delete_#{relationship}[]"
    )

    # Render the table component with relationship-specific context
    render TableComponent.new(
      collection: collection,
      config: config,
      current_params: relationship_params
    )
  end

  def link_unlink_controls
    content_tag :div, class: "mt-3" do
      content_tag :div, class: "d-flex justify-content-between align-items-center" do
        content_tag(:h6, "Available #{title}", class: "mb-0") +
        available_items_search
      end +
      available_items_table +
      link_unlink_modal
    end
  end

  def available_items_search
    content_tag :div, class: "d-flex" do
      content_tag(:input, "",
        type: "text",
        class: "form-control form-control-sm me-2",
        placeholder: "Search available #{title.downcase}...",
        style: "max-width: 200px;"
      ) +
      content_tag(:button, "Search", class: "btn btn-outline-secondary btn-sm")
    end
  end

  def available_items_table
    content_tag :div, class: "table-responsive mt-2" do
      content_tag :table, class: "table table-sm" do
        content_tag(:thead) do
          content_tag(:tr) do
            content_tag(:th, "Select", style: "width: 60px;") +
            content_tag(:th, "Name") +
            content_tag(:th, "Status") +
            content_tag(:th, "Actions", style: "width: 100px;")
          end
        end +
        content_tag(:tbody) do
          content_tag(:tr) do
            content_tag(:td, checkbox_tag("link_#{entity_name}[]", "1", false, class: "form-check-input")) +
            content_tag(:td, "Sample #{entity_name.humanize}") +
            content_tag(:td, content_tag(:span, "Available", class: "badge bg-success")) +
            content_tag(:td, link_to("Link", "#", class: "btn btn-primary btn-sm"))
          end
        end
      end
    end
  end

  def link_unlink_modal
    content_tag :div, class: "modal fade", id: "#{entity_name}LinkModal", tabindex: "-1" do
      content_tag :div, class: "modal-dialog modal-lg" do
        content_tag :div, class: "modal-content" do
          modal_header + modal_body + modal_footer
        end
      end
    end
  end

  def modal_header
    content_tag :div, class: "modal-header" do
      content_tag(:h5, "Link #{entity_name.humanize.pluralize}", class: "modal-title") +
      content_tag(:button, "&times;".html_safe,
        type: "button",
        class: "btn-close",
        data: { bs_dismiss: "modal" }
      )
    end
  end

  def modal_body
    content_tag :div, class: "modal-body" do
      content_tag(:p, "Select #{entity_name.humanize.pluralize} to link to this #{parent.class.name.downcase}:",
        class: "mb-3"
      ) +
      available_items_search +
      available_items_table
    end
  end

  def modal_footer
    content_tag :div, class: "modal-footer" do
      content_tag(:button, "Cancel",
        type: "button",
        class: "btn btn-secondary",
        data: { bs_dismiss: "modal" }
      ) +
      content_tag(:button, "Link Selected",
        type: "button",
        class: "btn btn-primary"
      )
    end
  end

  def add_edit_modals
    add_modal + edit_modal
  end

  def add_modal
    content_tag :div, class: "modal fade", id: "#{entity_name}AddModal", tabindex: "-1", style: "z-index: 1090;" do
      content_tag :div, class: "modal-dialog modal-lg" do
        content_tag :div, class: "modal-content" do
          add_modal_header + add_modal_body + add_modal_footer
        end
      end
    end
  end

  def add_modal_header
    content_tag :div, class: "modal-header" do
      content_tag(:h5, "Add #{entity_name.humanize}", class: "modal-title") +
      content_tag(:button, "&times;".html_safe,
        type: "button",
        class: "btn-close",
        data: { bs_dismiss: "modal" }
      )
    end
  end

  def add_modal_body
    content_tag :div, class: "modal-body" do
      helpers.turbo_frame_tag "#{entity_name}_form", src: helpers.send("new_#{parent.class.name.downcase}_#{entity_name}_path", parent) do
        content_tag(:div, "Loading form...", class: "text-center py-3")
      end
    end
  end

  def add_modal_footer
    content_tag :div, class: "modal-footer" do
      content_tag(:button, "Close",
        type: "button",
        class: "btn btn-secondary",
        data: { bs_dismiss: "modal" }
      )
    end
  end

  def edit_modal
    content_tag :div, class: "modal fade", id: "#{entity_name}EditModal", tabindex: "-1", style: "z-index: 1090;" do
      content_tag :div, class: "modal-dialog modal-lg" do
        content_tag :div, class: "modal-content" do
          edit_modal_header + edit_modal_body + edit_modal_footer
        end
      end
    end
  end

  def edit_modal_header
    content_tag :div, class: "modal-header" do
      content_tag(:h5, "Edit #{entity_name.humanize}", class: "modal-title") +
      content_tag(:button, "&times;".html_safe,
        type: "button",
        class: "btn-close",
        data: { bs_dismiss: "modal" }
      )
    end
  end

  def edit_modal_body
    content_tag :div, class: "modal-body" do
      helpers.turbo_frame_tag "#{entity_name}_form" do
        content_tag(:div, "Click a row to edit...", class: "text-center py-3 text-muted")
      end
    end
  end

  def edit_modal_footer
    content_tag :div, class: "modal-footer" do
      content_tag(:button, "Close",
        type: "button",
        class: "btn btn-secondary",
        data: { bs_dismiss: "modal" }
      )
    end
  end

  def get_relationship_collection
    # Get the data for this relationship from the parent
    if default && relationship_data_available?
      # Use pre-loaded data from controller if available
      helpers.instance_variable_get("@#{relationship}")
    else
      # Fallback to direct association access with pagination
      parent.send(relationship)
            .apply_table_sorting(relationship_params)
            .paginated_results(relationship_params)
    end
  end

  def relationship_data_available?
    # Check if the controller has pre-loaded this relationship data
    helpers.instance_variable_get("@#{relationship}").present?
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

    # Convert to hash then back to ActionController::Parameters
    ActionController::Parameters.new(relationship_specific_params.to_h)
  end
end