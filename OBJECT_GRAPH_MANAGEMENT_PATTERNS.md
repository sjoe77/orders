# Object Graph Management Patterns for Enterprise Rails Applications

## Overview

This document outlines comprehensive patterns for managing complex object graphs in Rails applications with enterprise-grade audit trails, optimistic concurrency control, and atomic save operations. These patterns provide a foundation for building maintainable, auditable systems that handle complex relationships while preserving data integrity.

## Core Principles

### 1. Parent-Managed Atomic Saves
All changes within an object graph are saved atomically when the parent object is saved. This ensures data consistency and provides clear audit trails.

### 2. Draft vs Persisted State Management
- **Draft Objects**: New, unsaved objects don't show relationship tables until persisted
- **Persisted Objects**: Saved objects display full relationship management capabilities

### 3. Granular Change Tracking
Every save operation is tracked with:
- Common reason key linking related changes
- Individual change records for each modified object
- Audit trail showing complete transaction context

## Relationship Management Patterns

### 1. Belongs To Relationship (1:M) - Simple Objects

**Example**: Customer → Addresses

**UI Pattern**:
- Show addresses table only after customer is persisted
- "Add" button opens dialog to add address to customer form
- Address changes remain unsaved until customer save
- All address modifications saved atomically with customer

**Implementation**:
```ruby
# Customer update with nested addresses
def update
  reason_key = SecureRandom.uuid

  ActiveRecord::Base.transaction do
    @customer.reason = "Customer and addresses update - #{reason_key}"

    # Nested attributes handle address creation/updates
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Customer and addresses saved successfully"
    else
      render :edit
    end
  end
rescue ActiveRecord::RecordInvalid => e
  render :edit, alert: "Update failed: #{e.message}"
end

private

def customer_params
  params.require(:customer).permit(:name, :email,
    addresses_attributes: [:id, :street, :city, :state, :zip, :_destroy])
end
```

### 2. Belongs To Relationship (1:M) - Complex Objects

**Example**: Customer → Orders (with Order Line Items)

**UI Pattern**:
- "Add" button on orders table opens new browser tab
- Order page contains line items table with its own "Add" functionality
- Order save includes all line items atomically
- Return to customer page with new order row added

**Implementation**:
```ruby
# Order with line items
def create
  ActiveRecord::Base.transaction do
    @order = @customer.orders.build(order_params)
    @order.reason = "Created order from customer page"

    if @order.save
      # Line items are saved as part of nested attributes
      redirect_to customer_path(@customer), notice: "Order created successfully"
    else
      render :new
    end
  end
rescue ActiveRecord::RecordInvalid => e
  render :new, alert: "Failed to create order: #{e.message}"
end
```

### 3. Many-to-Many Relationships (M:M)

**Example**: Product ↔ Categories

**UI Pattern**:
- Both sides are independent entities with their own main pages
- "Link" button (not "Add") opens dialog with existing objects
- Checkboxes for selecting multiple items to link/unlink
- Links save immediately with confirmation

**Implementation**:
```ruby
# Product-Category linking
def link_categories
  ActiveRecord::Base.transaction do
    reason = "Updated product categories from product page"

    # Remove existing links
    @product.product_categories.destroy_all

    # Create new links
    category_ids.each do |category_id|
      @product.product_categories.create!(
        category_id: category_id,
        reason: reason
      )
    end

    render json: { success: true, message: "Categories updated successfully" }
  end
rescue => e
  render json: { error: e.message }
end
```

## PaperTrail Integration with Common Reason Keys

### Configuration

```ruby
# In models
class Customer < ApplicationRecord
  has_paper_trail

  attr_accessor :reason

  before_save :set_paper_trail_reason

  private

  def set_paper_trail_reason
    PaperTrail.request.whodunnit = current_user&.id
    PaperTrail.request.controller_info = { reason: reason }
  end
end

class Address < ApplicationRecord
  belongs_to :customer
  has_paper_trail

  attr_accessor :reason
  before_save :set_paper_trail_reason

  private

  def set_paper_trail_reason
    PaperTrail.request.controller_info = { reason: reason }
  end
end
```

### Atomic Save with Shared Reason

```ruby
class CustomersController < ApplicationController
  def update
    reason_key = SecureRandom.uuid

    ActiveRecord::Base.transaction do
      # Set common reason for all changes in this transaction
      @customer.reason = "Customer update - #{reason_key}"

      if @customer.update(customer_params)
        # Handle nested address updates
        if params[:addresses_attributes]
          params[:addresses_attributes].each do |id, address_attrs|
            address = @customer.addresses.find(id)
            address.reason = "Address update - #{reason_key}"
            address.update!(address_attrs)
          end
        end

        redirect_to @customer, notice: "Customer updated successfully"
      else
        render :edit
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render :edit, alert: "Update failed: #{e.message}"
  end
end
```

## Optimistic Concurrency Control

### Model Setup

```ruby
class Customer < ApplicationRecord
  # Enable optimistic locking
  self.locking_column = :lock_version

  def stale?
    changed? && lock_version_changed?
  end
end
```

### Stale Save Detection

```ruby
def update
  begin
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Customer updated successfully"
    else
      render :edit
    end
  rescue ActiveRecord::StaleObjectError
    # Reload fresh data
    @customer.reload

    flash.now[:alert] = "Someone else has updated this customer. Please review the current data and try again."
    render :edit
  end
end
```

### Multi-Level Stale Detection

```ruby
# In forms, include lock_version for all objects
<%= form.hidden_field :lock_version %>

# Check for stale objects at each level
def update_order_with_line_items
  ActiveRecord::Base.transaction do
    # Check order staleness
    if @order.lock_version != params[:order][:lock_version].to_i
      raise ActiveRecord::StaleObjectError, "Order has been modified"
    end

    # Check line items staleness
    params[:order][:line_items_attributes]&.each do |id, attrs|
      line_item = @order.line_items.find(id)
      if line_item.lock_version != attrs[:lock_version].to_i
        raise ActiveRecord::StaleObjectError, "Line item #{id} has been modified"
      end
    end

    @order.update!(order_params)
  end
rescue ActiveRecord::StaleObjectError => e
  flash.now[:alert] = "Stale data detected: #{e.message}"
  @order.reload
  render :edit
end
```

## Timeline View Implementation

### Audit Trail Query

```ruby
class AuditService
  def self.customer_timeline(customer)
    # Get customer changes
    customer_versions = customer.versions.includes(:item)

    # Get level-1 association changes (addresses, orders)
    address_versions = PaperTrail::Version.where(
      item_type: 'Address',
      item_id: customer.address_ids
    )

    order_versions = PaperTrail::Version.where(
      item_type: 'Order',
      item_id: customer.order_ids
    )

    # Combine and sort by created_at
    all_versions = (customer_versions + address_versions + order_versions)
                  .sort_by(&:created_at)
                  .reverse

    group_by_reason(all_versions)
  end

  private

  def self.group_by_reason(versions)
    versions.group_by do |version|
      version.controller_info&.dig('reason') || 'Unknown reason'
    end
  end
end
```

### Timeline Display

```erb
<!-- Timeline view -->
<div class="timeline">
  <% AuditService.customer_timeline(@customer).each do |reason, versions| %>
    <div class="timeline-group">
      <h6><%= reason %></h6>
      <small class="text-muted"><%= versions.first.created_at.strftime("%B %d, %Y at %I:%M %p") %></small>

      <ul class="list-group mt-2">
        <% versions.each do |version| %>
          <li class="list-group-item">
            <strong><%= version.item_type %></strong>
            <span class="badge bg-<%= version_badge_color(version.event) %>">
              <%= version.event.humanize %>
            </span>
            <!-- Show specific changes -->
            <% if version.changeset.present? %>
              <ul class="small mt-1">
                <% version.changeset.each do |field, (old_val, new_val)| %>
                  <li><strong><%= field.humanize %>:</strong> <%= old_val %> → <%= new_val %></li>
                <% end %>
              </ul>
            <% end %>
          </li>
        <% end %>
      </ul>
    </div>
  <% end %>
</div>
```

## Bootstrap UI Implementation

### Responsive Relationship Tables

```erb
<!-- Customer edit page with related objects -->
<div class="container-fluid">
  <% if @customer.persisted? %>
    <%= render TabsComponent.new(id: "customer_tabs") do |tabs| %>
      <% tabs.with_tab(title: "Addresses", active: true) do %>
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h6>Addresses</h6>
          <button class="btn btn-sm btn-outline-primary"
                  data-bs-toggle="modal"
                  data-bs-target="#addressModal">
            <i class="bi bi-plus-circle"></i> Add Address
          </button>
        </div>
        <%= render 'addresses/table', addresses: @customer.addresses %>
      <% end %>

      <% tabs.with_tab(title: "Orders") do %>
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h6>Orders</h6>
          <a href="<%= new_customer_order_path(@customer) %>"
             class="btn btn-sm btn-outline-primary"
             target="_blank">
            <i class="bi bi-plus-circle"></i> Add Order
          </a>
        </div>
        <%= render 'orders/table', orders: @customer.orders %>
      <% end %>
    <% end %>
  <% else %>
    <div class="alert alert-info">
      <i class="bi bi-info-circle"></i>
      Save the customer first to manage related addresses and orders.
    </div>
  <% end %>
</div>
```

### Linking Dialog for M:M Relationships

```erb
<!-- Category linking modal for Product -->
<div class="modal fade" id="categoryModal">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Link Categories</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <%= form_with url: link_categories_product_path(@product),
                      method: :patch,
                      local: false do |form| %>
          <% Category.all.each do |category| %>
            <div class="form-check">
              <%= check_box_tag 'category_ids[]',
                                category.id,
                                @product.categories.include?(category),
                                id: "category_#{category.id}",
                                class: 'form-check-input' %>
              <%= label_tag "category_#{category.id}",
                           category.name,
                           class: 'form-check-label' %>
            </div>
          <% end %>
        <% end %>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
        <button type="submit" class="btn btn-primary">Save Links</button>
      </div>
    </div>
  </div>
</div>
```

## Enterprise Considerations

### Compliance and Audit Requirements

1. **Complete Audit Trail**: Every change is tracked with user, timestamp, and business reason
2. **Data Integrity**: Atomic transactions ensure consistency across related objects
3. **Conflict Resolution**: Optimistic locking prevents data corruption from concurrent edits
4. **Regulatory Compliance**: Audit logs provide evidence for compliance reporting

### Performance Optimizations

1. **Lazy Loading**: Relationship tables load on-demand via tabs
2. **Pagination**: Large datasets use cursor-based pagination
3. **Caching**: Frequently accessed audit data uses Rails cache
4. **Background Processing**: Complex audit reports run via background jobs

### Security Considerations

1. **Authorization**: Each relationship action checked against user permissions
2. **Input Validation**: All nested attributes validated before save
3. **SQL Injection Prevention**: Using parameterized queries throughout
4. **Audit Log Protection**: Version records are immutable after creation

## Git-Like Conflict Resolution Patterns

Enterprise applications require sophisticated conflict resolution when multiple users edit the same data simultaneously. This system implements Git-like conflict resolution with both client-side and server-side detection.

### Two-Level Stale Detection

#### 1. Client-Side Stale Detection (Relationship Table Refresh)

When users interact with relationship tables (addresses, orders), the client periodically fetches fresh data. If server state has changed, we detect conflicts before attempting save.

**Scenario**: User A edits customer address while User B also modifies addresses on the same customer.

```javascript
// Client-side stale detection in relationship tables
class ConflictResolver {
  async detectClientSideStaleState(relationshipType, parentId) {
    // Fetch fresh server data
    const serverData = await this.fetchFreshRelationshipData(relationshipType, parentId)
    const localChanges = this.getLocalChanges(relationshipType)

    // Compare lock versions
    const conflicts = this.detectConflicts(serverData, localChanges)

    if (conflicts.length > 0) {
      return this.showConflictResolutionDialog(conflicts)
    }

    return { resolved: true, mergedData: serverData }
  }

  detectConflicts(serverData, localChanges) {
    const conflicts = []

    Object.entries(localChanges).forEach(([id, localChange]) => {
      const serverRecord = serverData.find(r => r.id === id)

      if (serverRecord && serverRecord.lock_version !== localChange.original_lock_version) {
        conflicts.push({
          id,
          type: 'update_conflict',
          serverVersion: serverRecord,
          localVersion: localChange,
          fields: this.getChangedFields(serverRecord, localChange)
        })
      }
    })

    return conflicts
  }
}
```

#### 2. Server-Side Stale Detection (Final Save)

When the parent object (customer) is finally saved, Rails optimistic locking catches any remaining conflicts.

**Scenario**: User saves customer with address changes, but another user modified the customer or addresses in the meantime.

```ruby
# Enhanced server-side conflict resolution
class CustomersController < ApplicationController
  def update
    reason_key = SecureRandom.uuid

    ActiveRecord::Base.transaction do
      @customer.reason = "Customer and addresses update - #{reason_key}"

      if @customer.update(customer_params)
        redirect_to @customer, notice: t('customers.updated_successfully')
      else
        render :edit, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::StaleObjectError => e
    handle_server_side_conflict(e)
  end

  private

  def handle_server_side_conflict(error)
    # Reload ALL fresh data from server
    @customer.reload

    # Extract user's intended changes
    user_changes = customer_params.to_h

    # Build detailed conflict information
    conflicts = build_conflict_details(user_changes, error)

    # Store conflict data for resolution dialog
    session[:pending_conflicts] = {
      reason_key: SecureRandom.uuid,
      user_changes: user_changes,
      conflicts: conflicts,
      timestamp: Time.current
    }

    # Render conflict resolution dialog
    render :resolve_conflicts, status: :conflict
  end

  def build_conflict_details(user_changes, error)
    conflicts = []

    # Customer level conflicts
    if error.record == @customer
      conflicts << build_customer_conflict(user_changes)
    end

    # Address level conflicts
    if user_changes[:addresses_attributes]
      conflicts.concat(build_address_conflicts(user_changes[:addresses_attributes]))
    end

    conflicts
  end

  def build_customer_conflict(user_changes)
    {
      type: 'customer',
      entity_id: @customer.id,
      entity_type: 'Customer',
      user_version: user_changes,
      server_version: @customer.attributes,
      conflicted_fields: detect_field_conflicts(@customer.attributes, user_changes)
    }
  end

  def build_address_conflicts(address_changes)
    conflicts = []

    address_changes.each do |index, address_attrs|
      if address_attrs[:id].present?
        server_address = @customer.addresses.find_by(id: address_attrs[:id])
        if server_address
          conflicted_fields = detect_field_conflicts(server_address.attributes, address_attrs)
          if conflicted_fields.any?
            conflicts << {
              type: 'address',
              entity_id: server_address.id,
              entity_type: 'Address',
              user_version: address_attrs,
              server_version: server_address.attributes,
              conflicted_fields: conflicted_fields
            }
          end
        end
      end
    end

    conflicts
  end

  def detect_field_conflicts(server_attrs, user_attrs)
    conflicts = []

    user_attrs.each do |field, user_value|
      next if field.in?(['id', 'lock_version', '_destroy'])

      server_value = server_attrs[field]
      if server_value != user_value
        conflicts << {
          field: field,
          server_value: server_value,
          user_value: user_value,
          field_label: t("attributes.#{server_attrs['type']&.downcase || 'customer'}.#{field}", default: field.humanize)
        }
      end
    end

    conflicts
  end
end
```

### Conflict Resolution Dialog UI

#### Git-Style Three-Way Merge Interface

```erb
<!-- app/views/customers/resolve_conflicts.html.erb -->
<div class="conflict-resolution-container">
  <div class="alert alert-warning">
    <h5><i class="bi bi-exclamation-triangle"></i> Merge Conflicts Detected</h5>
    <p>Someone else has modified this data while you were editing. Please resolve the conflicts below.</p>
  </div>

  <%= form_with model: @customer, url: resolve_conflicts_customer_path(@customer),
                method: :patch,
                data: { controller: "conflict-resolver" } do |form| %>

    <% session[:pending_conflicts][:conflicts].each_with_index do |conflict, index| %>
      <div class="conflict-block mb-4 border rounded">
        <div class="conflict-header bg-light p-3 border-bottom">
          <h6 class="mb-0">
            <i class="bi bi-git-merge"></i>
            <%= conflict[:entity_type] %> #<%= conflict[:entity_id] %> Conflict
          </h6>
        </div>

        <div class="conflict-body p-3">
          <% conflict[:conflicted_fields].each do |field_conflict| %>
            <div class="field-conflict mb-3"
                 data-conflict-resolver-target="fieldConflict"
                 data-field="<%= field_conflict[:field] %>">

              <label class="form-label fw-bold"><%= field_conflict[:field_label] %></label>

              <!-- Three-column Git-style merge view -->
              <div class="row g-2">
                <!-- Your Changes -->
                <div class="col-md-4">
                  <div class="conflict-option" data-option="user">
                    <div class="conflict-header bg-success bg-opacity-10 p-2 rounded-top border">
                      <small class="fw-bold text-success">
                        <i class="bi bi-person"></i> Your Changes
                      </small>
                    </div>
                    <div class="conflict-content p-2 border border-top-0 rounded-bottom">
                      <code class="user-bg"><%= field_conflict[:user_value] %></code>
                      <div class="mt-2">
                        <%= radio_button_tag "conflicts[#{index}][#{field_conflict[:field]}]",
                                           "user", false,
                                           class: "form-check-input",
                                           data: { action: "change->conflict-resolver#selectResolution" } %>
                        <%= label_tag "conflicts_#{index}_#{field_conflict[:field]}_user",
                                     "Use My Version",
                                     class: "form-check-label ms-1" %>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Server Changes -->
                <div class="col-md-4">
                  <div class="conflict-option" data-option="server">
                    <div class="conflict-header bg-info bg-opacity-10 p-2 rounded-top border">
                      <small class="fw-bold text-info">
                        <i class="bi bi-server"></i> Server Version
                      </small>
                    </div>
                    <div class="conflict-content p-2 border border-top-0 rounded-bottom">
                      <code class="server-bg"><%= field_conflict[:server_value] %></code>
                      <div class="mt-2">
                        <%= radio_button_tag "conflicts[#{index}][#{field_conflict[:field]}]",
                                           "server", false,
                                           class: "form-check-input",
                                           data: { action: "change->conflict-resolver#selectResolution" } %>
                        <%= label_tag "conflicts_#{index}_#{field_conflict[:field]}_server",
                                     "Use Server Version",
                                     class: "form-check-label ms-1" %>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Manual Merge -->
                <div class="col-md-4">
                  <div class="conflict-option" data-option="manual">
                    <div class="conflict-header bg-warning bg-opacity-10 p-2 rounded-top border">
                      <small class="fw-bold text-warning">
                        <i class="bi bi-pencil"></i> Manual Merge
                      </small>
                    </div>
                    <div class="conflict-content p-2 border border-top-0 rounded-bottom">
                      <%= text_field_tag "conflicts[#{index}][#{field_conflict[:field]}]",
                                        "",
                                        class: "form-control form-control-sm",
                                        placeholder: "Enter merged value...",
                                        data: {
                                          action: "input->conflict-resolver#enableManualOption",
                                          manual_field: field_conflict[:field]
                                        } %>
                      <div class="mt-2">
                        <%= radio_button_tag "conflicts[#{index}][#{field_conflict[:field]}]",
                                           "manual", false,
                                           class: "form-check-input",
                                           disabled: true,
                                           data: {
                                             action: "change->conflict-resolver#selectResolution",
                                             manual_radio: field_conflict[:field]
                                           } %>
                        <%= label_tag "conflicts_#{index}_#{field_conflict[:field]}_manual",
                                     "Use Manual Merge",
                                     class: "form-check-label ms-1" %>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <!-- Conflict Resolution Actions -->
    <div class="d-flex justify-content-between align-items-center mt-4 p-3 bg-light rounded">
      <div class="conflict-summary" data-conflict-resolver-target="summary">
        <small class="text-muted">
          <span data-conflict-resolver-target="resolvedCount">0</span> of
          <span data-conflict-resolver-target="totalCount"><%= session[:pending_conflicts][:conflicts].sum { |c| c[:conflicted_fields].length } %></span>
          conflicts resolved
        </small>
      </div>

      <div class="action-buttons">
        <%= link_to "Cancel & Reload", edit_customer_path(@customer),
                    class: "btn btn-secondary me-2" %>

        <%= form.submit "Apply Resolution & Save",
                       class: "btn btn-success",
                       data: {
                         conflict_resolver_target: "submitButton",
                         disabled: true
                       } %>
      </div>
    </div>

    <!-- Hidden field to store resolution data -->
    <%= hidden_field_tag :conflict_resolution_token, session[:pending_conflicts][:reason_key] %>
  <% end %>
</div>
```

#### Conflict Resolution JavaScript Controller

```javascript
// app/javascript/controllers/conflict_resolver_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fieldConflict", "summary", "resolvedCount", "totalCount", "submitButton"]

  connect() {
    this.updateSummary()
  }

  selectResolution(event) {
    const fieldConflict = event.target.closest('[data-conflict-resolver-target="fieldConflict"]')
    const field = fieldConflict.dataset.field

    // Update visual feedback
    this.updateFieldSelection(fieldConflict, event.target.value)

    // Update summary
    this.updateSummary()
  }

  enableManualOption(event) {
    const field = event.target.dataset.manualField
    const manualRadio = document.querySelector(`[data-manual-radio="${field}"]`)

    if (event.target.value.trim()) {
      manualRadio.disabled = false
      manualRadio.checked = true
      this.selectResolution({ target: manualRadio })
    } else {
      manualRadio.disabled = true
      manualRadio.checked = false
    }

    this.updateSummary()
  }

  updateFieldSelection(fieldElement, option) {
    // Remove previous selection styling
    fieldElement.querySelectorAll('.conflict-option').forEach(opt => {
      opt.classList.remove('selected')
    })

    // Add selection styling
    const selectedOption = fieldElement.querySelector(`[data-option="${option}"]`)
    if (selectedOption) {
      selectedOption.classList.add('selected')
    }
  }

  updateSummary() {
    const totalConflicts = this.fieldConflictTargets.length
    const resolvedConflicts = this.fieldConflictTargets.filter(field => {
      return field.querySelector('input[type="radio"]:checked')
    }).length

    this.resolvedCountTarget.textContent = resolvedConflicts
    this.totalCountTarget.textContent = totalConflicts

    // Enable submit button only when all conflicts are resolved
    this.submitButtonTarget.disabled = resolvedConflicts < totalConflicts
  }
}
```

### Advanced Conflict Resolution

#### Multi-Level Lock Version Tracking

```ruby
# Enhanced optimistic locking for nested objects
class Customer < ApplicationRecord
  has_many :addresses, dependent: :destroy
  accepts_nested_attributes_for :addresses, allow_destroy: true

  # Track lock versions for all nested objects
  before_save :sync_nested_lock_versions

  private

  def sync_nested_lock_versions
    # Ensure all nested objects have current lock versions
    addresses.each do |address|
      if address.persisted? && address.changed?
        # Verify the address hasn't been modified by another process
        fresh_address = Address.find(address.id)
        if fresh_address.lock_version != address.lock_version
          raise ActiveRecord::StaleObjectError.new(address, "update")
        end
      end
    end
  end
end
```

#### Automatic Conflict Resolution Rules

```ruby
# Service for automatic conflict resolution based on business rules
class ConflictResolutionService
  def self.auto_resolve_conflicts(conflicts, resolution_strategy = :user_wins)
    auto_resolved = []
    manual_required = []

    conflicts.each do |conflict|
      resolution = attempt_auto_resolution(conflict, resolution_strategy)

      if resolution
        auto_resolved << { conflict: conflict, resolution: resolution }
      else
        manual_required << conflict
      end
    end

    {
      auto_resolved: auto_resolved,
      manual_required: manual_required
    }
  end

  private

  def self.attempt_auto_resolution(conflict, strategy)
    case strategy
    when :user_wins
      # User changes always win (for draft-like workflows)
      :user
    when :server_wins
      # Server changes always win (for published content)
      :server
    when :timestamp_wins
      # Most recent change wins
      conflict[:user_timestamp] > conflict[:server_timestamp] ? :user : :server
    when :field_specific
      # Different rules for different fields
      auto_resolve_by_field(conflict)
    else
      nil # Require manual resolution
    end
  end

  def self.auto_resolve_by_field(conflict)
    # Example: Some fields auto-resolve, others require manual intervention
    case conflict[:field]
    when 'is_default_flag'
      :user # User's boolean flags typically win
    when 'address_line1_txt', 'city_nm'
      nil # Address fields require manual review
    when 'updated_at', 'lock_version'
      :server # System fields always use server version
    else
      nil
    end
  end
end
```

### Enterprise Conflict Resolution Requirements

1. **Complete Audit Trail**: Every conflict resolution is logged with user decisions
2. **Conflict Prevention**: Real-time collaboration indicators (showing who else is editing)
3. **Auto-Save Drafts**: Periodic auto-save to prevent work loss during conflicts
4. **Role-Based Resolution**: Different resolution rules based on user permissions
5. **Conflict Notifications**: Email/Slack notifications when conflicts occur
6. **Compliance Reporting**: Detailed reports showing all conflict resolutions for audits

This Git-like conflict resolution pattern ensures data integrity while providing users with clear, intuitive tools for resolving editing conflicts in enterprise applications.

## Summary

This object graph management pattern provides:

- **Atomic Operations**: All related changes saved together or rolled back
- **Clear Audit Trails**: Every change linked by common reason keys
- **Git-Like Conflict Resolution**: Two-level stale detection with intuitive merge UI
- **Conflict Prevention**: Optimistic locking at all levels
- **Flexible UI**: Different patterns for different relationship types
- **Enterprise Ready**: Meets audit, compliance, and performance requirements

The pattern scales from simple 1:M relationships to complex object graphs while maintaining data integrity and providing comprehensive conflict resolution suitable for enterprise applications.