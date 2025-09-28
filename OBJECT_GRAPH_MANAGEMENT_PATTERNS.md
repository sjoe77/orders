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

### 3. Many-to-Many Relationships (M:M) - Enterprise Implementation

**Example**: Product ↔ Categories

**UI Pattern**:
- Both sides are independent entities with their own main pages
- "Manage" button opens Bootstrap modal with search and pagination
- Checkboxes for selecting multiple items to link/unlink
- **Pending Changes Pattern**: Changes stored in JSON field until parent form submission
- Real-time search with debounced input
- Bulk operations (Select All/Clear All)

**Component Architecture**:
```ruby
# ViewComponent for M:M relationship management
class ManyToManyTabComponent < ViewComponent::Base
  def initialize(parent:, relationship:, link_action_path:)
    @parent = parent
    @relationship = relationship.to_s
    @link_action_path = link_action_path
    @frame_id = "#{parent.class.name.downcase}_#{@relationship}"
    @title = @relationship.humanize
  end

  def relationship_class
    parent.class.reflect_on_association(relationship.to_sym)&.klass
  end

  def current_items_paginated
    items = current_items.limit(10).offset(0)
    OpenStruct.new(
      records: items,
      current_page: 1,
      total_pages: 1,
      per_page: 10,
      total_count: current_items.count,
      empty?: items.empty?
    )
  end

  def data_attributes
    {
      'many-to-many-relationship-type' => relationship,
      'many-to-many-link-action-path' => link_action_path,
      'many-to-many-frame-id' => frame_id
    }
  end
end
```

**Stimulus Controller Integration**:
```javascript
// app/javascript/controllers/many_to_many_controller.js
export default class extends Controller {
  static targets = ["searchInput", "itemsList", "itemCheckbox", "selectedCount", "saveButton"]

  saveChanges() {
    const selectedIds = this.itemCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)

    const relationshipType = this.data.get('relationshipType')

    // Store changes in pending_changes field for later processing
    this.storePendingChanges(relationshipType, selectedIds)

    // Close modal and show feedback
    const modal = bootstrap.Modal.getInstance(this.element.closest('.modal'))
    modal?.hide()
    this.showNotification('Relationship changes saved. Submit the form to apply changes.', 'success')
  }

  storePendingChanges(relationshipType, selectedIds) {
    const mainForm = document.querySelector('[data-controller*="graph-form"]')
    const pendingChangesField = mainForm.querySelector('[data-graph-form-target="pendingChanges"]')

    let pendingChanges = {}
    try {
      if (pendingChangesField.value) {
        pendingChanges = JSON.parse(pendingChangesField.value)
      }
    } catch (e) {
      pendingChanges = {}
    }

    // Store M:M relationship changes
    pendingChanges[`${relationshipType}_ids`] = selectedIds
    pendingChangesField.value = JSON.stringify(pendingChanges)

    // Trigger change event for graph-form controller
    pendingChangesField.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
```

**Server-Side Implementation with Audit Trails**:
```ruby
# Enhanced Product controller with M:M relationship handling
class ProductsController < ApplicationController
  include NestedAttributesProcessor

  def update
    audit_transaction = nil

    ActiveRecord::Base.transaction do
      user_reason = product_params[:audit_reason].presence || "Product update"

      # Create audit transaction with parent context
      audit_transaction = AuditTransaction.create!(
        reason: user_reason,
        user_id: nil, # TODO: Set to current_user.id
        item: @product,
        operation_status: 'SUCCESS',
        created_at: Time.current
      )

      PaperTrail.request.whodunnit = nil
      PaperTrail.request.controller_info = {
        audit_transaction_id: audit_transaction.id
      }

      # Process pending changes including M:M relationships
      merged_params = process_pending_changes(product_params)
      merged_params.delete(:audit_reason)

      # Extract M:M relationship changes
      category_ids = merged_params.delete('categories_ids')

      if @product.update(merged_params)
        # Handle M:M relationship changes if present
        if category_ids.present?
          @product.product_categories.destroy_all
          category_ids.each do |category_id|
            @product.product_categories.create!(category_id: category_id)
          end
        end

        flash[:notice] = 'Product was successfully updated.'
        redirect_to edit_product_path(@product)
      else
        render :edit, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::StaleObjectError => e
    handle_stale_object_conflict(e, audit_transaction)
  end

  private

  def handle_stale_object_conflict(stale_error, audit_transaction = nil)
    if audit_transaction
      audit_transaction.update!(
        operation_status: 'CONFLICT_RESOLVED',
        resolution_type: 'AUTO_RESOLVED_PATCH_REPLAY',
        conflict_details: {
          stale_record_type: stale_error.record.class.name,
          stale_record_id: stale_error.record.id,
          attempted_operation: stale_error.attempted_action,
          resolution_method: 'patch_replay'
        }
      )
    end

    @product.reload
    user_changes = product_params
    replay_user_patches(user_changes)

    flash.now[:alert] = "Someone else modified this record. Your changes have been applied to the current data. Please review and save again."
    render :edit, status: :unprocessable_entity
  end
end
```

**Enhanced NestedAttributesProcessor for M:M Support**:
```ruby
# Extended processor to handle M:M relationship IDs
module NestedAttributesProcessor
  def process_pending_changes(params)
    return params.except(:pending_changes) unless params[:pending_changes].present?

    begin
      pending_changes = JSON.parse(params[:pending_changes])
    rescue JSON::ParserError
      return params.except(:pending_changes)
    end

    merged_params = params.except(:pending_changes).to_h

    # Handle M:M relationship IDs (e.g., categories_ids, products_ids)
    pending_changes.each do |key, value|
      if key.end_with?('_ids') && value.is_a?(Array)
        merged_params[key] = value.map(&:to_s).reject(&:blank?)
      elsif key.end_with?('_attributes') && value.is_a?(Hash)
        # Handle nested attributes as before
        # ... existing nested attributes logic
      end
    end

    merged_params
  end
end
```

## Enhanced Audit Transaction System

### Audit Transaction Schema

The `audit_transactions` table captures comprehensive operation metadata beyond standard PaperTrail versioning:

```ruby
# Enhanced audit_transactions table structure
create_table :audit_transactions do |t|
  t.string :reason, null: false                    # Business reason for the operation
  t.timestamp :created_at, null: false             # When the operation occurred
  t.integer :user_id, null: true                   # Who performed the operation
  t.integer :item_id, null: true                   # Parent entity ID (polymorphic)
  t.string :item_type, null: true                  # Parent entity type (polymorphic)
  t.string :operation_status, null: false          # SUCCESS, CONFLICT_RESOLVED, CONFLICT_FAILED
  t.string :resolution_type, null: true            # How conflicts were resolved
  t.json :conflict_details, null: true             # Detailed conflict metadata
end
```

### Operation Status Tracking

#### **operation_status** Field Values:

1. **SUCCESS**: Operation completed without conflicts
   ```ruby
   audit_transaction = AuditTransaction.create!(
     reason: "Product update with category changes",
     operation_status: 'SUCCESS',
     item: @product
   )
   ```

2. **CONFLICT_RESOLVED**: Operation encountered conflicts but was automatically resolved
   ```ruby
   audit_transaction.update!(
     operation_status: 'CONFLICT_RESOLVED',
     resolution_type: 'AUTO_RESOLVED_PATCH_REPLAY',
     conflict_details: {
       stale_record_type: 'Product',
       resolution_method: 'patch_replay_with_mm_preservation'
     }
   )
   ```

3. **CONFLICT_FAILED**: Operation failed due to unresolvable conflicts
   ```ruby
   audit_transaction.update!(
     operation_status: 'CONFLICT_FAILED',
     resolution_type: 'VALIDATION_ERROR',
     conflict_details: {
       error_message: "Required field cannot be empty",
       user_input_preserved: true
     }
   )
   ```

### Resolution Type Categories

#### **resolution_type** Field Values:

1. **AUTO_RESOLVED_PATCH_REPLAY**: Automatic conflict resolution via patch replay
2. **AUTO_RESOLVED_LINK_CONFLICT**: M:M relationship conflicts resolved automatically
3. **MANUAL_RESOLUTION_REQUIRED**: Conflicts requiring user intervention
4. **VALIDATION_ERROR**: Failed due to business rule violations
5. **LINK_OPERATION_ERROR**: M:M relationship operation failures
6. **STALE_OBJECT_RECOVERY**: Recovery from optimistic locking conflicts

### Conflict Details JSON Structure

The `conflict_details` field captures comprehensive conflict metadata:

```json
{
  "stale_record_type": "Product",
  "stale_record_id": 123,
  "attempted_operation": "update",
  "resolution_method": "patch_replay_with_mm_preservation",
  "user_changes_preserved": ["name_nm", "categories_ids"],
  "server_changes_detected": ["updated_at", "lock_version"],
  "mm_relationship_conflicts": {
    "categories": {
      "user_intended_count": 3,
      "server_current_count": 2,
      "conflict_resolution": "user_intent_preserved"
    }
  },
  "performance_metrics": {
    "conflict_detection_ms": 45,
    "resolution_time_ms": 120,
    "total_operation_ms": 890
  }
}
```

### Enterprise Audit Reporting

#### Success Rate Analytics
```ruby
# Operation success rates by entity type
success_rate = AuditTransaction.where(item_type: 'Product')
  .group(:operation_status)
  .count

# M:M relationship operation reliability
mm_operations = AuditTransaction.where("reason LIKE ?", "%categories%")
  .group(:operation_status, :resolution_type)
  .count
```

#### Conflict Resolution Metrics
```ruby
# Automatic vs manual conflict resolution rates
resolution_effectiveness = AuditTransaction
  .where(operation_status: 'CONFLICT_RESOLVED')
  .group(:resolution_type)
  .count

# Average conflict resolution time
avg_resolution_time = AuditTransaction
  .where(operation_status: 'CONFLICT_RESOLVED')
  .average("(conflict_details->>'resolution_time_ms')::integer")
```

#### Compliance Reporting
```ruby
# Complete audit trail for regulatory compliance
def generate_compliance_report(entity, date_range)
  audit_transactions = AuditTransaction
    .where(item: entity, created_at: date_range)
    .includes(:paper_trail_versions)

  {
    total_operations: audit_transactions.count,
    success_rate: calculate_success_rate(audit_transactions),
    conflict_incidents: audit_transactions.where.not(operation_status: 'SUCCESS').count,
    data_integrity_preserved: all_conflicts_resolved?(audit_transactions),
    user_actions_tracked: audit_transactions.where.not(user_id: nil).count,
    mm_relationship_changes: count_mm_operations(audit_transactions)
  }
end
```

### Business Intelligence Integration

#### Operation Pattern Analysis
```ruby
# Identify high-conflict operations for process improvement
conflict_hotspots = AuditTransaction
  .where(operation_status: ['CONFLICT_RESOLVED', 'CONFLICT_FAILED'])
  .group(:item_type, :resolution_type)
  .having('COUNT(*) > ?', 10)
  .count

# User behavior patterns
user_conflict_patterns = AuditTransaction
  .joins("LEFT JOIN users ON users.id = audit_transactions.user_id")
  .where.not(operation_status: 'SUCCESS')
  .group('users.email', :operation_status)
  .count
```

#### Performance Monitoring
```ruby
# Track system performance under conflict conditions
performance_metrics = AuditTransaction
  .where("conflict_details ? 'performance_metrics'")
  .pluck("conflict_details->'performance_metrics'")
  .map { |metrics| JSON.parse(metrics) }

avg_conflict_detection_time = performance_metrics
  .map { |m| m['conflict_detection_ms'] }
  .sum / performance_metrics.size
```

This enhanced audit transaction system provides enterprise-grade operation tracking with detailed success/failure analysis, automatic conflict resolution documentation, and comprehensive business intelligence capabilities for continuous process improvement.

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

## M:M Relationship Conflict Resolution and Stale Save Strategy

### The Challenge

Many-to-many relationships present unique challenges for conflict resolution because:
1. **Multiple Entry Points**: Changes can originate from either side of the relationship
2. **Concurrent Link/Unlink Operations**: Multiple users can modify relationships simultaneously
3. **Complex Pending Changes**: M:M changes mixed with entity field changes in pending_changes JSON
4. **Audit Trail Complexity**: Need to track both link creation/deletion and parent entity changes

### Enterprise M:M Conflict Resolution Strategy

#### 1. Dual-Path Conflict Detection

**Path A: Immediate M:M Operations** (via direct AJAX)
```ruby
# Direct M:M linking with conflict detection
def link_categories
  audit_transaction = nil
  user_reason = "Updated product categories from product page"

  ActiveRecord::Base.transaction do
    # Create audit transaction
    audit_transaction = AuditTransaction.create!(
      reason: user_reason,
      user_id: nil,
      item: @product,
      operation_status: 'SUCCESS',
      created_at: Time.current
    )

    PaperTrail.request.controller_info = {
      audit_transaction_id: audit_transaction.id
    }

    # Get submitted category IDs from JSON array
    selected_ids_json = params[:selected_ids]
    category_ids = if selected_ids_json.present?
      JSON.parse(selected_ids_json).map(&:to_s).reject(&:blank?)
    else
      (params[:category_ids] || []).reject(&:blank?)
    end

    # Remove existing links and create new ones atomically
    @product.product_categories.destroy_all
    category_ids.each do |category_id|
      @product.product_categories.create!(category_id: category_id)
    end

    render json: {
      success: true,
      message: "Categories updated successfully",
      category_count: category_ids.length
    }
  end
rescue ActiveRecord::StaleObjectError => e
  handle_link_categories_conflict(e, audit_transaction)
rescue StandardError => e
  audit_transaction&.update!(
    operation_status: 'CONFLICT_FAILED',
    resolution_type: 'LINK_OPERATION_ERROR',
    conflict_details: { error_message: e.message }
  )
  render json: { error: e.message }, status: :unprocessable_entity
end
```

**Path B: Pending Changes Integration** (via parent form submission)
```ruby
# Enhanced update method handling M:M relationships in pending changes
def update
  audit_transaction = nil

  ActiveRecord::Base.transaction do
    user_reason = product_params[:audit_reason].presence || "Product update"

    audit_transaction = AuditTransaction.create!(
      reason: user_reason,
      user_id: nil,
      item: @product,
      operation_status: 'SUCCESS',
      created_at: Time.current
    )

    # Process pending changes including M:M relationships
    merged_params = process_pending_changes(product_params)
    category_ids = merged_params.delete('categories_ids')

    if @product.update(merged_params)
      # Handle M:M relationship changes atomically with parent update
      if category_ids.present?
        @product.product_categories.destroy_all
        category_ids.each do |category_id|
          @product.product_categories.create!(category_id: category_id)
        end
      end

      flash[:notice] = 'Product was successfully updated.'
      redirect_to edit_product_path(@product)
    else
      render :edit, status: :unprocessable_entity
    end
  end
rescue ActiveRecord::StaleObjectError => e
  handle_comprehensive_stale_conflict(e, audit_transaction)
end
```

#### 2. M:M Relationship State Synchronization

**Enhanced Stimulus Controller with Conflict Detection**:
```javascript
// Real-time relationship conflict detection
export default class extends Controller {
  static targets = ["searchInput", "itemsList", "itemCheckbox", "selectedCount", "saveButton"]

  connect() {
    this.updateSelectedCount()
    this.attachSearchListener()
    this.startConflictDetection()
  }

  async checkForRelationshipConflicts() {
    const linkActionPath = this.data.get('linkActionPath')
    const parentId = linkActionPath.match(/\/(\d+)\//)?.[1]
    const relationshipType = this.data.get('relationshipType')

    if (!parentId || !relationshipType) return

    try {
      const response = await fetch(`/api/relationship_state/${relationshipType}/${parentId}`)
      const serverState = await response.json()
      const currentSelections = this.getCurrentSelections()

      if (this.hasConflicts(serverState.linked_ids, currentSelections)) {
        this.showConflictWarning(serverState)
      }
    } catch (error) {
      console.warn('Conflict detection failed:', error)
    }
  }

  saveChanges() {
    const selectedIds = this.getCurrentSelections()
    const relationshipType = this.data.get('relationshipType')

    // Store changes in pending_changes field for transactional integrity
    this.storePendingChanges(relationshipType, selectedIds)

    const modal = bootstrap.Modal.getInstance(this.element.closest('.modal'))
    modal?.hide()

    this.showNotification('Relationship changes saved. Submit the form to apply changes.', 'success')
  }

  storePendingChanges(relationshipType, selectedIds) {
    const mainForm = document.querySelector('[data-controller*="graph-form"]')
    const pendingChangesField = mainForm.querySelector('[data-graph-form-target="pendingChanges"]')

    let pendingChanges = {}
    try {
      if (pendingChangesField.value) {
        pendingChanges = JSON.parse(pendingChangesField.value)
      }
    } catch (e) {
      pendingChanges = {}
    }

    // Store M:M relationship changes with metadata
    pendingChanges[`${relationshipType}_ids`] = selectedIds
    pendingChanges[`${relationshipType}_change_timestamp`] = new Date().toISOString()

    pendingChangesField.value = JSON.stringify(pendingChanges)
    pendingChangesField.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
```

#### 3. Enterprise Audit Trail for M:M Operations

**Comprehensive M:M Audit Tracking**:
```ruby
# Enhanced audit transaction model with M:M relationship support
class AuditTransaction < ApplicationRecord
  belongs_to :item, polymorphic: true, optional: true
  has_many :paper_trail_versions, class_name: 'PaperTrail::Version',
           foreign_key: 'audit_transaction_id', dependent: :nullify

  # M:M specific audit scopes
  scope :mm_relationship_operations, -> { where("reason LIKE ?", "%categories%") }
  scope :conflicted_operations, -> { where(operation_status: ['CONFLICT_RESOLVED', 'CONFLICT_FAILED']) }

  def mm_relationship_summary
    return {} unless conflict_details.present?

    {
      relationship_type: extract_relationship_type,
      links_added: count_links_added,
      links_removed: count_links_removed,
      conflict_resolution_method: resolution_type,
      user_intent_preserved: operation_status == 'SUCCESS'
    }
  end

  private

  def extract_relationship_type
    case reason
    when /categories/ then 'product_categories'
    when /products/ then 'category_products'
    else 'unknown'
    end
  end

  def count_links_added
    paper_trail_versions.where(event: 'create', item_type: 'ProductCategory').count
  end

  def count_links_removed
    paper_trail_versions.where(event: 'destroy', item_type: 'ProductCategory').count
  end
end
```

### Best Practices for M:M Conflict Resolution

#### 1. **Transactional Integrity**
- Always wrap M:M operations in database transactions
- Use audit transactions to group related M:M and entity changes
- Implement proper rollback strategies for partial failures

#### 2. **User Experience Optimization**
- Provide real-time conflict detection with periodic checks
- Show clear visual feedback when conflicts are detected
- Allow users to choose between server state and their changes

#### 3. **Audit Compliance**
- Track both successful M:M operations and conflict resolutions
- Store complete context including user intent and resolution method
- Maintain immutable audit trail for regulatory compliance

#### 4. **Performance Considerations**
- Use efficient conflict detection queries
- Implement client-side caching for relationship state
- Batch M:M operations to minimize database round trips

#### 5. **Scalability Patterns**
- Consider using message queues for high-volume M:M operations
- Implement optimistic UI updates with server-side validation
- Use read replicas for conflict detection queries

This comprehensive M:M relationship management pattern ensures data integrity while providing enterprise-grade conflict resolution and audit trails suitable for complex business applications.