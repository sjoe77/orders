class AuditHistoryViewerComponent < ViewComponent::Base
  def initialize(record:, max_entries: 5, page: 1, **options)
    @record = record
    @max_entries = max_entries
    @page = page.to_i
    @options = options
  end

  private

  attr_reader :record, :max_entries, :page, :options

  def audit_entries
    @audit_entries ||= fetch_audit_entries
  end

  def fetch_audit_entries
    # Use audit transactions instead of individual versions for enterprise object graph auditing
    offset = (page - 1) * max_entries

    # Get audit transactions for this entity and its relationships using the enterprise pattern
    audit_transactions = AuditTransaction.audit_scope_for_entity(record)
                                        .recent
                                        .includes(:versions)
                                        .limit(max_entries)
                                        .offset(offset)

    audit_transactions
  rescue StandardError => e
    Rails.logger.error "AuditHistoryViewerComponent error: #{e.message}"
    []
  end

  def component_id
    @component_id ||= "audit_history_#{record.class.name.underscore}_#{record.id}"
  end

  def format_event_type(event)
    case event
    when 'create'
      { icon: 'bi-plus-circle', text: 'Created', class: 'text-success' }
    when 'update'
      { icon: 'bi-pencil', text: 'Updated', class: 'text-primary' }
    when 'destroy'
      { icon: 'bi-trash', text: 'Deleted', class: 'text-danger' }
    else
      { icon: 'bi-question-circle', text: event.humanize, class: 'text-muted' }
    end
  end

  def format_timestamp(timestamp)
    return '' unless timestamp
    # Convert UTC to local time and format
    timestamp.in_time_zone.strftime('%m/%d/%Y %I:%M %p')
  end

  def format_whodunnit(version)
    return 'System' if version.whodunnit.blank?

    # Try to find user by ID if whodunnit is numeric
    if version.whodunnit.match?(/^\d+$/)
      user = find_user_by_id(version.whodunnit)
      return user.name if user&.respond_to?(:name)
      return user.email if user&.respond_to?(:email)
      return "User #{version.whodunnit}"
    end

    version.whodunnit
  end

  def find_user_by_id(user_id)
    return nil unless defined?(User)
    User.find_by(id: user_id)
  rescue StandardError
    nil
  end

  def format_reason(version)
    return '' unless version.respond_to?(:reason)

    reason = version.reason
    return '' if reason.blank?

    reason
  end

  def get_changes_summary(version)
    return {} unless version.changeset

    begin
      changes = version.changeset || {}
      summarize_changes(changes)
    rescue StandardError
      {}
    end
  end

  def summarize_changes(changes)
    return {} if changes.blank?

    # Filter out timestamp and audit fields
    filtered_changes = changes.except(
      'created_at', 'updated_at', 'id',
      'reason', 'reason_key', 'lock_version'
    )

    filtered_changes.transform_values do |change_array|
      next change_array unless change_array.is_a?(Array) && change_array.length == 2

      {
        from: format_change_value(change_array[0]),
        to: format_change_value(change_array[1])
      }
    end
  end

  def format_change_value(value)
    case value
    when nil
      '<empty>'
    when true
      '✓'
    when false
      '✗'
    when String
      value.length > 50 ? "#{value[0..47]}..." : value
    when Numeric
      value.to_s
    when Time, DateTime, Date
      value.strftime('%m/%d/%Y')
    else
      value.to_s
    end
  end

  def changes_count(version)
    changes = get_changes_summary(version)
    changes.keys.count
  end

  def has_reason?(version)
    format_reason(version).present?
  end

  def reason_key(version)
    return '' unless version.respond_to?(:controller_info)

    controller_info = version.controller_info || {}
    controller_info['reason_key'] || controller_info[:reason_key] || ''
  end

  def show_details?
    options.fetch(:show_details, true)
  end

  def show_changes?
    options.fetch(:show_changes, true)
  end

  def collapsed_by_default?
    options.fetch(:collapsed, true)
  end

  def total_versions_count
    @total_versions_count ||= begin
      # Count audit transactions for this entity and its relationships
      AuditTransaction.audit_scope_for_entity(record).count
    rescue StandardError
      0
    end
  end

  def current_page
    page
  end

  def total_pages
    return 1 if total_versions_count == 0
    (total_versions_count.to_f / max_entries).ceil
  end

  def has_next_page?
    current_page < total_pages
  end

  def has_previous_page?
    current_page > 1
  end

  def next_page
    current_page + 1 if has_next_page?
  end

  def previous_page
    current_page - 1 if has_previous_page?
  end

  def showing_entries_text
    start_entry = ((current_page - 1) * max_entries) + 1
    end_entry = [current_page * max_entries, total_versions_count].min

    if total_versions_count == 0
      "No entries"
    elsif total_versions_count == 1
      "Showing 1 entry"
    else
      "Showing #{start_entry}-#{end_entry} of #{total_versions_count} entries"
    end
  end

  def pagination_id
    "#{component_id}_pagination"
  end

  # Render the individual versions within a transaction
  def render_transaction_versions(versions)
    return "" unless versions.any?

    content = versions.map do |version|
      event_info = format_event_type(version.event)
      changes = get_changes_summary(version)

      # Build the content for each version
      version_content = ""

      # Version header
      version_content += content_tag(:div, class: "d-flex align-items-center mb-2") do
        content_tag(:span, class: "me-2") do
          content_tag(:i, '', class: "#{event_info[:icon]} #{event_info[:class]}") +
          " " +
          content_tag(:strong, "#{version.item_type}")
        end +
        content_tag(:small, class: "text-muted") do
          "##{version.item_id} #{event_info[:text].downcase}"
        end
      end

      # Changes for this version
      if version.event == 'update' && changes.any?
        changes_content = changes.map do |field, change|
          content_tag(:div, class: "row small mb-1") do
            content_tag(:div, "#{field.humanize}:", class: "col-4 fw-bold text-muted") +
            content_tag(:div, class: "col-8") do
              if change.is_a?(Hash) && change[:from] && change[:to]
                content_tag(:span, change[:from], class: "text-danger text-decoration-line-through me-2") +
                " → " +
                content_tag(:span, change[:to], class: "text-success ms-2")
              else
                change.to_s
              end
            end
          end
        end.join.html_safe

        version_content += content_tag(:div, changes_content, class: "ps-3 border-start border-2 border-light")
      end

      content_tag(:div, version_content.html_safe, class: "mb-3")
    end.join.html_safe

    content
  end
end