import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    recordType: String,
    recordId: Number
  }

  loadPage(event) {
    event.preventDefault()

    const page = event.currentTarget.dataset.page
    const modal = document.getElementById('auditHistoryModal')
    const modalBody = modal.querySelector('.modal-body')

    // Show loading indicator
    modalBody.innerHTML = `
      <div class="text-center py-4">
        <div class="spinner-border text-primary" role="status">
          <span class="visually-hidden">Loading...</span>
        </div>
        <p class="mt-2 text-muted">Loading audit history...</p>
      </div>
    `

    // Fetch new content
    const url = `/customers/${this.recordIdValue}/audit_page?page=${page}`

    fetch(url, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      modalBody.innerHTML = html
    })
    .catch(error => {
      console.error('Error loading audit history page:', error)
      modalBody.innerHTML = `
        <div class="text-center text-danger py-4">
          <i class="bi bi-exclamation-triangle fs-1"></i>
          <p class="mb-0">Error loading audit history</p>
          <small>Please try again</small>
        </div>
      `
    })
  }
}