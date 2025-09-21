# Rails Template: Solution Developer Guide
## Generic Infrastructure vs Solution Control

This guide explains what the generic Rails template handles automatically versus what solution developers control and customize.

## Philosophy: Infrastructure vs Presentation

**Generic Template Provides**: The "plumbing" - consistent patterns, auto-detection, standard workflows, and infrastructure components.

**Solution Controls**: The "presentation" - field layouts, business logic, styling preferences, and domain-specific behaviors.

---

## PageHeaderComponent: Convention-Based Infrastructure

### What the Template Auto-Detects
- **Current Record**: Automatically finds `@customer`, `@order`, etc. from controller context
- **Page Context**: Determines edit vs new mode from `record.persisted?`
- **Standard Actions**: Generates appropriate CRUD buttons based on context
- **Form Integration**: Connects to graph-form controller for audit trails
- **Modal Infrastructure**: Creates update confirmation and audit history modals

### What Solutions Control
- **Custom Titles**: Override via I18n or slot content
- **Action Visibility**: Choose which buttons to show/hide
- **Form Design**: Complete control over `_form` partial layout
- **Styling**: Entity-specific CSS and layout preferences
- **Business Logic**: Custom validation, workflows, and rules

### Usage Examples

**Minimal (uses all conventions):**
```erb
<%= render PageHeaderComponent.new %>
```

**With Solution Overrides:**
```erb
<%= render PageHeaderComponent.new do |header| %>
  <% header.with_title do %>
    <%= t('customers.edit_title', name: @customer.company_name_nm) %>
  <% end %>
  <% header.with_actions do %>
    <!-- Custom action buttons -->
  <% end %>
<% end %>
```

---

## RelationshipTableComponent: Flexible Relationship Management

### What the Template Provides
- **Auto-Discovery**: Finds relationships via model introspection
- **Sorting & Pagination**: Turbo Frame integration without page refresh
- **Standard Actions**: Create, edit, delete, view patterns
- **Modal Integration**: Seamless modal workflows for editing

### What Solutions Control
- **Tab Organization**: Order and grouping of relationship tabs
- **Action Configuration**: Which actions to enable per relationship type
- **Custom Labels**: I18n-based titles and descriptions
- **Business Rules**: Which relationships to show based on business logic

### Usage Examples

**Basic Relationship Display:**
```erb
<%= render TabsComponent.new(id: "customer_relationships") do |tabs| %>
  <% tabs.with_tab(title: t('customers.tabs.contact_info'), active: true) do %>
    <%= render RelationshipTableComponent.new(
      title: t('customers.relationships.addresses.title'),
      records: @customer.addresses,
      actions: { create: true, edit: true, delete: true }
    ) %>
  <% end %>

  <% tabs.with_tab(title: t('customers.tabs.order_history')) do %>
    <%= render RelationshipTableComponent.new(
      title: t('customers.relationships.orders.title'),
      records: @customer.orders,
      actions: { view: true }
    ) %>
  <% end %>
<% end %>
```

---

## Form Architecture: Solution-Owned Presentation

### What the Template Provides
- **Graph-Form Controller**: Manages object graphs and audit trails
- **Modal Infrastructure**: Standard modal dialogs for relationship editing
- **Validation Display**: Consistent error message formatting
- **Turbo Integration**: Seamless form submissions without page refresh

### What Solutions Control
- **Field Layout**: Complete control over form structure and organization
- **Field Order**: Business-driven field sequencing
- **Input Types**: Choice of form controls and widgets
- **Validation Rules**: Domain-specific validation logic
- **Help Text**: Contextual guidance and instructions

### Form Organization Patterns

**Solution Form Partial (`app/views/customers/_form.html.erb`):**
```erb
<%= form_with model: customer, local: true, id: "customer_form",
              data: {
                controller: "graph-form",
                graph_form_entity_type_value: "customer"
              } do |form| %>

  <!-- Solution Controls Field Layout -->
  <div class="row">
    <div class="col-md-6">
      <div class="mb-3">
        <%= form.label :customer_key_nm, t('attributes.customer.customer_key_nm'), class: 'form-label' %>
        <%= form.text_field :customer_key_nm, class: 'form-control' %>
      </div>
    </div>

    <div class="col-md-6">
      <div class="mb-3">
        <%= form.label :company_name_nm, t('attributes.customer.company_name_nm'), class: 'form-label' %>
        <%= form.text_field :company_name_nm, class: 'form-control' %>
      </div>
    </div>
  </div>

  <!-- Solution Controls Business Logic -->
  <% if customer.persisted? && current_user.can_edit_credit_limit? %>
    <div class="mb-3">
      <%= form.label :credit_limit_amt, t('attributes.customer.credit_limit_amt'), class: 'form-label' %>
      <%= form.number_field :credit_limit_amt, class: 'form-control' %>
    </div>
  <% end %>
<% end %>
```

---

## I18n Integration: Enterprise-Grade Localization

### Required I18n Structure

**`config/locales/en.yml`:**
```yaml
en:
  # Entity Names
  entities:
    customer:
      singular: "Customer"
      plural: "Customers"
    order:
      singular: "Order"
      plural: "Orders"

  # Attributes
  attributes:
    customer:
      customer_key_nm: "Customer ID"
      company_name_nm: "Company Name"
      contact_first_name_nm: "First Name"
      credit_limit_amt: "Credit Limit"

  # Page Titles (Auto-Generated)
  page_titles:
    edit: "Edit %{entity}"
    new: "New %{entity}"

  # Relationship Tabs
  customers:
    tabs:
      contact_info: "Contact Information"
      order_history: "Order History"
    relationships:
      addresses:
        title: "Addresses"
      orders:
        title: "Orders"

  # Standard Actions
  actions:
    create: "Create"
    update: "Update"
    delete: "Delete"
    cancel: "Cancel"
    view_audit: "View Audit History"
```

### Convention-Based I18n Keys

The template automatically looks for keys in this pattern:
- **Page Titles**: `page_titles.edit`, `page_titles.new`
- **Entity Names**: `entities.{controller_name}.singular`
- **Standard Actions**: `actions.create`, `actions.update`, etc.

---

## File Organization: Template vs Solution

### Generic Template Files (`app/components/`)
```
app/components/
├── page_header_component.rb          # Infrastructure
├── relationship_table_component.rb   # Infrastructure
├── tabs_component.rb                 # Infrastructure
├── modal_dialog_manager_component.rb # Infrastructure
└── table_component.rb               # Infrastructure
```

### Solution-Specific Files (`app/views/`)
```
app/views/
├── customers/
│   ├── _form.html.erb               # Solution controls layout
│   ├── edit.html.erb                # Solution controls presentation
│   └── index.html.erb               # Solution controls table design
├── orders/
│   ├── _form.html.erb               # Solution controls layout
│   └── edit.html.erb                # Solution controls presentation
└── shared/
    └── _custom_form_widgets.html.erb # Solution-specific widgets
```

---

## Business Logic: Solution Domain

### What Solutions Own Completely
- **Validation Rules**: Domain-specific business validation
- **Security**: User permissions and access control
- **Workflow Logic**: Business process implementation
- **Data Transformation**: Entity-specific formatting and calculations
- **Integration Points**: External system connections

### Example: Solution Business Logic
```ruby
# app/models/customer.rb (Solution-owned)
class Customer < ApplicationRecord
  # Solution controls validation rules
  validates :customer_key_nm, presence: true, uniqueness: true
  validates :credit_limit_amt, numericality: { greater_than: 0 }

  # Solution controls business logic
  def can_place_order?
    active_flag && credit_limit_amt > outstanding_balance
  end

  # Solution controls data presentation
  def display_name
    company_name_nm.presence || "#{contact_first_name_nm} #{contact_last_name_nm}"
  end
end
```

---

## Customization Patterns

### Override Template Defaults
```erb
<!-- Use template defaults -->
<%= render PageHeaderComponent.new %>

<!-- Override with solution-specific content -->
<%= render PageHeaderComponent.new do |header| %>
  <% header.with_title do %>
    <%= t('customers.edit_advanced_title', customer: @customer.display_name) %>
  <% end %>
<% end %>
```

### Solution-Specific Styling
```scss
// app/assets/stylesheets/customers.scss (Solution-owned)
.customer-form {
  .credit-limit-section {
    background: #f8f9fa;
    padding: 1rem;
    border-radius: 0.375rem;
  }
}
```

---

## Summary: Clean Separation of Concerns

| Aspect | Template Provides | Solution Controls |
|--------|------------------|-------------------|
| **Structure** | Page layout, navigation, responsive design | Form layouts, field organization |
| **Functionality** | CRUD patterns, sorting, pagination | Business validation, workflows |
| **Styling** | Base components, consistent patterns | Entity-specific styling, branding |
| **Content** | Standard actions, auto-generated titles | Custom labels, help text, messaging |
| **Behavior** | Form submission, modal handling | Business logic, user permissions |

This separation ensures the template provides robust infrastructure while solutions maintain complete control over their unique requirements and presentation preferences.