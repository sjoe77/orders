import { Controller } from "@hotwired/stimulus"

// Controller to handle individual checkbox changes and update delete button visibility
export default class extends Controller {
  connect() {
    this.updateDeleteButton()
  }

  updateDeleteButton() {
    // Find all delete checkboxes in the current relationship section
    const relationshipSection = this.element.closest('.relationship-section')
    if (!relationshipSection) return

    const checkboxes = relationshipSection.querySelectorAll('.delete-checkbox')
    const deleteButton = relationshipSection.querySelector('[id^="delete-selected-"]')

    if (!deleteButton) return

    // Enable/disable delete button and update styling based on whether any checkboxes are checked
    const checkedCount = Array.from(checkboxes).filter(cb => cb.checked).length
    const anyChecked = checkedCount > 0

    deleteButton.disabled = !anyChecked

    if (anyChecked) {
      deleteButton.classList.remove('btn-outline-danger')
      deleteButton.classList.add('btn-danger')
    } else {
      deleteButton.classList.remove('btn-danger')
      deleteButton.classList.add('btn-outline-danger')
    }

    // Update button text with count
    const icon = deleteButton.querySelector('i')
    const text = checkedCount > 0 ? ` Delete Selected (${checkedCount})` : ' Delete Selected'
    deleteButton.innerHTML = (icon ? icon.outerHTML : '<i class="bi bi-trash"></i>') + text
  }
}