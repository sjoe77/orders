# Rails Template Project with Bootstrap and ViewComponents

## Project Objective

This repository serves as a professional Rails application template designed to accelerate future Rails app development using Bootstrap 5+ and ViewComponents architecture for maximum maintainability and component reusability.

## Core Features

### UI Architecture
- **Responsive Navigation**: Bootstrap-powered responsive navigation with sliding drawer behavior
  - **Navigation drawer**: Slides content area instead of overlaying
  - **Bootstrap header**: Hamburger menu, app title, theme toggle, avatar, logout
  - **Responsive behavior**: Automatic adaptation across screen sizes
- **ViewComponent Architecture**: Reusable, testable UI components with slots
- **Bootstrap Theme System**: Seamless dark/light theme support using data-bs-theme

### Navigation Behavior
- Navigation drawer slides and resizes content area (not overlay)
- Bootstrap-compliant styling with CSS custom properties
- Turbo Frame integration for SPA-like table interactions
- Stimulus controllers for JavaScript functionality

### UI Components (Bootstrap + ViewComponents)
- **Bootstrap Icons**: Using Bootstrap Icons for consistent iconography
- **ViewComponent Slots**: Flexible component composition with `renders_one`/`renders_many`
- **Bootstrap Grid**: Responsive grid system with utility classes
- **Theme-aware Components**: CSS custom properties for automatic theme adaptation

### Entity CRUD Pattern
The template implements a consistent pattern for managing entities:

1. **Main Entity Table**: Bootstrap-styled tables with:
   - Responsive design and proper typography scaling
   - Turbo Frame pagination (10 rows per page)
   - Clickable rows for navigation
   - No action buttons (streamlined UX)

2. **Entity Instance Page**: Individual entity views with:
   - Bootstrap card layouts for entity details
   - Form components with proper validation
   - Related object tables via ViewComponents

## Design Principles

### Simplicity First
- **SIMPLICITY TRUMPS ALL CONCERNS**
- **MAINTAINABILITY IS KEY**
- ViewComponents with explicit dependency injection
- Bootstrap-compliant styling for future upgrade compatibility
- Clean separation of concerns between utilities and services

### ViewComponent Architecture
- **Explicit Dependency Injection**: No helper method leakage
- **Testable Components**: Individual component testing capability
- **Slots-based Composition**: Flexible component structure
- **Service Object Integration**: Clean separation of formatting and business logic

## Technical Stack
- Rails 8.x with modern defaults (Turbo, Stimulus, Propshaft)
- Bootstrap 5.3+ via CDN for responsive UI framework
- ViewComponent gem for component architecture
- Bootstrap Icons for consistent iconography
- Built-in dark/light theme support with CSS custom properties

## Architecture Patterns

### ViewComponent Structure
```erb
<%= render AppShellComponent.new do |shell| %>
  <% shell.with_header do %>
    <%= render HeaderComponent.new(title: "App Title") do |header| %>
      <% header.with_actions do %>
        <!-- Theme toggle, avatar, logout buttons -->
      <% end %>
    <% end %>
  <% end %>
  <% shell.with_navigation do %>
    <%= render NavigationComponent.new %>
  <% end %>
  <% shell.with_main_content do %>
    <%= yield %>
  <% end %>
<% end %>
```

### Service Object Pattern
- **app/lib/**: Utility classes (TableFormatter, PaginationRenderer)
- **app/services/**: Business logic services
- **Dependency Injection**: Components receive dependencies via initializer

```ruby
class TableComponent < ViewComponent::Base
  def initialize(collection:, config:, formatter: TableFormatter.new, paginator: PaginationRenderer.new)
    @formatter = formatter
    @paginator = paginator
  end
end
```

## File Organization

### Component Architecture
- **app/components/**: ViewComponent classes and templates
- **app/lib/**: Utility classes for formatting and rendering
- **app/services/**: Business logic and domain services
- **No app/helpers/**: Eliminated to prevent method collision

### Styling Architecture
- **Bootstrap 5.3+ utilities**: Consistent spacing, typography, colors
- **CSS custom properties**: Theme-aware styling (`var(--bs-primary)`)
- **No !important overrides**: Bootstrap-compliant for seamless upgrades

## Theme Support
Bootstrap-native theme system with automatic component adaptation:
- Themes via `data-bs-theme="dark"` or `data-bs-theme="light"`
- CSS custom properties for theme-aware colors
- Stimulus controller for theme persistence and icon updates

## Future Development
This template provides a robust foundation for professional Rails applications with:
- **Component Reusability**: ViewComponents eliminate ERB partial limitations
- **Bootstrap Compatibility**: Future-proof styling for framework upgrades
- **Testing Strategy**: Individual component testing with dependency injection
- **Clean Architecture**: Explicit dependencies prevent helper method collision