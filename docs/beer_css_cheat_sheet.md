# Beer CSS Cheat Sheet

## Table Components

### Basic Table Structure
```html
<table class="border stripes">
  <thead>
    <tr>
      <th class="left-align">Name</th>
      <th class="right-align">Amount</th>
      <th class="center-align">Actions</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Content</td>
      <td class="right-align">$123.45</td>
      <td class="center-align">
        <button class="transparent circle small">
          <i>edit</i>
        </button>
      </td>
    </tr>
  </tbody>
</table>
```

### Table Classes
- `border` - Adds borders to table cells
- `stripes` - Alternating row colors
- `fixed` - Fixed header during scroll

### Scrollable Table
```html
<div class="scroll small-height">
  <table class="fixed border">
    <!-- table content -->
  </table>
</div>
```

## Button Components

### Action Buttons
```html
<!-- Icon buttons -->
<button class="transparent circle small">
  <i>edit</i>
</button>

<button class="transparent circle small">
  <i>delete</i>
</button>

<!-- Primary action -->
<button class="primary">
  <i>add</i>
  <span>New Customer</span>
</button>
```

## Grid System

### Responsive Grid
```html
<div class="grid">
  <div class="s12 m6 l4">Small: 12, Medium: 6, Large: 4</div>
  <div class="s12 m6 l8">Small: 12, Medium: 6, Large: 8</div>
</div>
```

### Screen Size Classes
- `s1-s12` - Small screens (mobile)
- `m1-m12` - Medium screens (tablet)
- `l1-l12` - Large screens (desktop)

## Alignment Classes
- `left-align` - Left align content
- `right-align` - Right align content (numbers, currency)
- `center-align` - Center align content (actions, booleans)

## Spacing Classes
- `no-space` - No spacing
- `space` - Default spacing
- `small-space` - Small spacing
- `medium-space` - Medium spacing
- `large-space` - Large spacing

## Form Components

### Input Fields
```html
<div class="field">
  <input type="text" />
  <label>Search</label>
</div>

<div class="field">
  <select>
    <option value="">All</option>
    <option value="active">Active</option>
  </select>
  <label>Status</label>
</div>
```

## Navigation/Pagination
```html
<nav class="pagination">
  <button class="transparent">
    <i>chevron_left</i>
  </button>
  <span>1 of 10</span>
  <button class="transparent">
    <i>chevron_right</i>
  </button>
</nav>
```

## Container Classes
- `responsive` - Responsive container
- `scroll` - Scrollable container
- `small-height`, `medium-height`, `large-height` - Height constraints