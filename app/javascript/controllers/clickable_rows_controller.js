import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  rowClicked(event) {
    // Don't trigger if clicking on buttons or links
    if (event.target.closest('a, button')) {
      return
    }

    const row = event.currentTarget
    const customerId = row.dataset.customerId

    if (customerId) {
      window.location.href = `/customers/${customerId}/edit`
    }
  }
}