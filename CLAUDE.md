# Rails Template Project with Beer CSS

## Project Objective

This repository serves as a professional Rails application template designed to accelerate future Rails app development using Beer CSS Material Design system for maximum simplicity and maintainability.

## Core Features

### UI Architecture
- **Responsive Navigation**: Automatic responsive behavior with different navigation patterns for different screen sizes
  - **Large screens**: Expanded left navigation drawer with full menu labels
  - **Medium screens**: Compact left navigation with icons and labels
  - **Small screens**: Bottom navigation bar with icons only
- **Persistent Header**: Navigation header with app title, theme toggle, and user actions
- **Content Area**: Dynamic page content that updates without reloading the persistent shell
- **Material Design**: Clean, modern Material Design interface with built-in theming

### Navigation Behavior
- Beer CSS handles all responsive navigation behavior automatically
- No complex JavaScript required for drawer management
- Seamless navigation with Turbo for SPA-like experience
- Built-in smooth animations and transitions

### UI Components (Beer CSS Material Design)
- **Material Icons**: Using Google Material Icons (`<i>icon_name</i>`)
- **Layout Components**: Simple semantic HTML with Beer CSS classes
- **Responsive Grid**: Built-in responsive grid system (`s12 m6 l3`)
- **Form Controls**: Material Design form components
- **Cards & Containers**: Clean Material Design containers (`<article>`)

### Entity CRUD Pattern
The template implements a consistent pattern for managing entities:

1. **Main Entity Table**: Clean data tables with:
   - Responsive design for all screen sizes
   - Material Design styling
   - Create new instance functionality  
   - Delete existing instances
   
2. **Entity Instance Page**: Clicking a table row navigates to individual entity view with:
   - Display of entity details in Material Design cards
   - Edit functionality via Material Design forms
   - Related object tables based on foreign key relationships

## Design Principles

### Simplicity First
- **SIMPLICITY TRUMPS ALL CONCERNS**
- **MAINTAINABILITY IS KEY** 
- No complex implementations - Beer CSS handles everything
- Standard HTML with CSS classes - no custom components
- Clean, understandable code patterns

### Beer CSS Architecture
- **No ViewComponents**: Simple HTML with Beer CSS classes
- **No complex Stimulus controllers**: Beer CSS handles navigation
- **CDN-delivered**: No gem dependencies for UI framework
- **Built-in theming**: Dark/light themes work automatically

## Technical Stack
- Rails 8.x with modern defaults (Turbo, Stimulus, Propshaft)
- Beer CSS via CDN for Material Design UI
- Material Icons for consistent iconography
- Responsive design with automatic responsive behavior
- Built-in dark/light theme support

## Layout Structure

### Application Layout
```erb
<body data-controller="app-shell">
  <!-- Left Navigation Drawer (Large screens) -->
  <nav class="left max l">
    <header>
      <nav>
        <button class="circle transparent" data-action="click->app-shell#toggleTheme">
          <i>light_mode</i>
        </button>
        <h6 class="max">App Title</h6>
        <button class="circle transparent">
          <i>logout</i>
        </button>
      </nav>
    </header>
    <a href="/"><i>home</i><div>Home</div></a>
    <!-- More navigation items -->
  </nav>

  <!-- Compact Navigation (Medium screens) -->
  <nav class="left m">
    <!-- Compact navigation items -->
  </nav>

  <!-- Bottom Navigation (Small screens) -->
  <nav class="bottom s">
    <!-- Bottom navigation items -->
  </nav>

  <!-- Main Content Area -->
  <main class="responsive">
    <%= yield %>
  </main>
</body>
```

### Responsive Classes
- `l` (large): Shows on large screens only
- `m` (medium): Shows on medium screens only  
- `s` (small): Shows on small screens only
- `responsive`: Auto-adjusts for content area

## Theme Support
Built-in dark/light theme toggle with persistent storage:
- Themes applied via body class: `class="dark"` or `class="light"`
- Icons automatically update: `light_mode` ↔ `dark_mode`
- All Material Design components respect theme automatically

## Future Development
This template provides a solid foundation for rapid development of professional Rails applications with:
- Minimal code complexity (80% reduction vs ViewComponent approach)
- Built-in responsive behavior
- Material Design consistency
- Easy maintenance and updates