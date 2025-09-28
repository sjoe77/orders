import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  connect() {
    console.log('🔗 Clickable rows controller connected!', this.element)
  }

  rowClicked(event) {
    console.log('🔥 Row clicked!', event.currentTarget)

    const recordId = event.currentTarget.dataset.recordId
    const entityName = this.getEntityNameFromContext()

    console.log('🔍 recordId:', recordId, 'entityName:', entityName)

    if (recordId && entityName) {
      const editUrl = `/${entityName}/${recordId}/edit`
      console.log('🔍 Navigating to:', editUrl)
      window.location.href = editUrl
    }
  }

  getEntityNameFromContext() {
    console.log('🔍 getEntityNameFromContext called')

    // Fall back to extracting from the current URL path
    const currentPath = window.location.pathname
    console.log('🔍 currentPath:', currentPath)

    // Match patterns like /entities, /items, /records
    const pathMatches = currentPath.match(/^\/([^\/]+)(?:\/|$)/)
    console.log('🔍 pathMatches:', pathMatches)
    if (pathMatches) {
      const pathSegment = pathMatches[1]
      console.log('🔍 pathSegment:', pathSegment)

      // Skip generic segments and return the entity name
      if (!['edit', 'new', 'show'].includes(pathSegment)) {
        console.log('🔍 Returning pathSegment:', pathSegment)
        return pathSegment
      }
    }

    // If no pattern matches, return null
    console.log('🔍 No entity name found, returning null')
    return null
  }
}