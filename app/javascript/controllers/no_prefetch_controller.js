import { Controller } from "@hotwired/stimulus"

// Prevents hover prefetching on pagination and sorting links
export default class extends Controller {
  static targets = ["link"]

  connect() {
    // Find all pagination and sorting links within this controller's scope
    const links = this.element.querySelectorAll('a[data-turbo-frame]')

    links.forEach(link => {
      // Prevent mouseenter events that trigger prefetching
      link.addEventListener('mouseenter', this.preventPrefetch.bind(this))
      link.addEventListener('mouseover', this.preventPrefetch.bind(this))

      // Also try disabling via data attributes
      link.setAttribute('data-turbo-preload', 'false')
      link.setAttribute('data-turbo-prefetch', 'false')
    })
  }

  preventPrefetch(event) {
    // Stop the event from propagating to Turbo's event listeners
    event.stopImmediatePropagation()
    event.preventDefault()
  }
}