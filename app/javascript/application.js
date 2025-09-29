// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Disable Turbo prefetching globally to prevent hover requests
import { Turbo } from "@hotwired/turbo-rails"
document.addEventListener("DOMContentLoaded", () => {
  // Disable all prefetching
  if (Turbo && Turbo.config) {
    Turbo.config.preload = false
  }

  // Also disable via session if available
  if (Turbo && Turbo.session) {
    Turbo.session.preloadOnHover = false
  }

  // Intercept Turbo preload events and stop them
  document.addEventListener('turbo:before-prefetch', (event) => {
    event.preventDefault()
    event.stopImmediatePropagation()
  }, { capture: true })

  // Also intercept mouseenter events on links globally
  document.addEventListener('mouseenter', (event) => {
    if (event.target.matches('a[data-turbo-frame]')) {
      event.stopImmediatePropagation()
    }
  }, { capture: true })
})
