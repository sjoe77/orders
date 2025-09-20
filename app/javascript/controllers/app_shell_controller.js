import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "content", "themeToggle"]

  connect() {
    console.log('🔄 STIMULUS CONNECT - START')
    console.log('- Current URL:', window.location.pathname)
    console.log('- Element classes before:', this.element.className)

    // Flag that Stimulus has connected
    window.stimulusConnected = true

    // Initialize drawer state from localStorage
    const storedState = localStorage.getItem('drawerOpen')
    this.isDrawerOpen = storedState === 'true'

    console.log('- Stored state:', storedState, 'isDrawerOpen:', this.isDrawerOpen)

    this.setupTheme()
    this.disableViewTransitions()
    this.setupKeyboardEvents()
    this.restoreDrawerState()

    console.log('- Element classes after:', this.element.className)
    console.log('🔄 STIMULUS CONNECT - END')
  }

  disconnect() {
    console.log('❌ STIMULUS DISCONNECT - URL:', window.location.pathname)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  toggleDrawer(event) {
    event.preventDefault()

    this.isDrawerOpen = !this.isDrawerOpen

    // Toggle the drawer-open class on the app shell
    if (this.isDrawerOpen) {
      this.element.classList.add('drawer-open')
      localStorage.setItem('drawerOpen', 'true')
    } else {
      this.element.classList.remove('drawer-open')
      localStorage.setItem('drawerOpen', 'false')
    }
  }

  navigateAndClose(event) {
    const link = event.currentTarget
    const currentPath = window.location.pathname
    const targetPath = new URL(link.href).pathname

    // If clicking the same page, prevent navigation
    if (currentPath === targetPath) {
      event.preventDefault()
      return
    }

    // Only close drawer on mobile - desktop drawer stays open
    if (this.isMobile() && this.isDrawerOpen) {
      this.isDrawerOpen = false
      this.element.classList.remove('drawer-open')
      localStorage.setItem('drawerOpen', 'false')
    }
  }

  restoreDrawerState() {
    console.log('🎯 RESTORE DRAWER STATE - START')
    console.log('- isDrawerOpen:', this.isDrawerOpen)
    console.log('- Element classes before no-transition:', this.element.className)

    // Temporarily disable transitions to prevent animation on page load
    this.element.classList.add('no-transition')
    console.log('- Added no-transition, classes now:', this.element.className)

    // Apply the current state using CSS classes
    if (this.isDrawerOpen) {
      console.log('- Adding drawer-open class')
      this.element.classList.add('drawer-open')
    } else {
      console.log('- Removing drawer-open class')
      this.element.classList.remove('drawer-open')
    }

    console.log('- Final classes with drawer state:', this.element.className)

    // Re-enable transitions after a brief delay
    setTimeout(() => {
      console.log('- Removing no-transition class')
      this.element.classList.remove('no-transition')
      console.log('- Final classes after timeout:', this.element.className)
    }, 10)

    console.log('🎯 RESTORE DRAWER STATE - END')
  }

  setupKeyboardEvents() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.isDrawerOpen) {
      this.isDrawerOpen = false
      this.element.classList.remove('drawer-open')
      localStorage.setItem('drawerOpen', 'false')
    }
  }

  isMobile() {
    return window.innerWidth < 1024
  }

  setupTheme() {
    // Get saved theme from localStorage or default to light
    this.currentTheme = localStorage.getItem('theme') || 'light'
    this.applyTheme(this.currentTheme)
  }

  toggleTheme(event) {
    event.preventDefault()
    this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light'
    this.applyTheme(this.currentTheme)
    localStorage.setItem('theme', this.currentTheme)
  }

  applyTheme(theme) {
    // Apply Bootstrap theme using data-bs-theme attribute
    document.documentElement.setAttribute('data-bs-theme', theme)

    // Update all theme toggle icons
    const themeButtons = document.querySelectorAll('[data-app-shell-target="themeToggle"] i, [data-action*="toggleTheme"] i')
    themeButtons.forEach(icon => {
      this.updateThemeIcon(icon, theme)
    })
  }

  updateThemeIcon(iconElement, theme) {
    // Remove existing Bootstrap icon classes
    iconElement.className = iconElement.className.replace(/bi-[\w-]+/g, '').trim()

    if (theme === 'dark') {
      iconElement.classList.add('bi', 'bi-moon-fill')
    } else {
      iconElement.classList.add('bi', 'bi-sun-fill')
    }
  }

  disableViewTransitions() {
    // Disable browser view transitions by intercepting the API
    if (document.startViewTransition) {
      const originalStartViewTransition = document.startViewTransition
      document.startViewTransition = function(callback) {
        // Just call the callback directly without starting a view transition
        if (callback) callback()
      }
    }
  }
}