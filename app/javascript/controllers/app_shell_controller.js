import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "content", "themeToggle"]

  connect() {
    // Flag that Stimulus has connected
    window.stimulusConnected = true
    console.log('App shell controller connected successfully')
    
    this.setupTheme()
    this.disableViewTransitions()
    this.setupKeyboardEvents()
    this.restoreDrawerState()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  toggleDrawer(event) {
    event.preventDefault()
    this.isDrawerOpen = !this.isDrawerOpen
    
    if (this.isDrawerOpen) {
      this.drawerTarget.style.transform = "translateX(0)"
      // Content scoots right to make room for drawer
      const drawerWidth = this.drawerTarget.offsetWidth || 320
      this.contentTarget.style.marginLeft = `${drawerWidth}px`
      localStorage.setItem('drawerOpen', 'true')
    } else {
      this.drawerTarget.style.transform = "translateX(-100%)"
      // Content scoots back to left
      this.contentTarget.style.marginLeft = "0px"
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
    if (this.isMobile()) {
      this.isDrawerOpen = false
      this.drawerTarget.style.transform = "translateX(-100%)"
    }
  }

  restoreDrawerState() {
    // Check localStorage for drawer state
    const storedState = localStorage.getItem('drawerOpen')
    const drawerWasOpen = storedState === 'true'
    this.isDrawerOpen = drawerWasOpen
    
    console.log('Restoring drawer state:', storedState, 'isOpen:', this.isDrawerOpen)
    
    // Apply the stored state
    if (this.isDrawerOpen) {
      this.drawerTarget.style.transform = "translateX(0)"
      // Restore content position for open drawer  
      const drawerWidth = this.drawerTarget.offsetWidth || 320
      this.contentTarget.style.marginLeft = `${drawerWidth}px`
      console.log('Drawer restored as open')
    } else {
      this.drawerTarget.style.transform = "translateX(-100%)"
      this.contentTarget.style.marginLeft = "0px"
      // Only set to false if it was null/undefined
      if (storedState === null) {
        localStorage.setItem('drawerOpen', 'false')
      }
      console.log('Drawer restored as closed')
    }
  }

  setupKeyboardEvents() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.isDrawerOpen) {
      this.isDrawerOpen = false
      this.drawerTarget.style.transform = "translateX(-100%)"
      // Content scoots back to left when ESC closes drawer
      this.contentTarget.style.marginLeft = "0px"
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
    // Apply theme to body class for Beer CSS
    document.body.className = document.body.className.replace(/\b(light|dark)\b/g, '').trim()
    document.body.classList.add(theme)
    
    // Update all theme toggle icons
    const themeButtons = document.querySelectorAll('[data-app-shell-target="themeToggle"] i, [data-action*="toggleTheme"] i')
    themeButtons.forEach(icon => {
      this.updateThemeIcon(icon, theme)
    })
  }

  updateThemeIcon(iconElement, theme) {
    if (theme === 'dark') {
      iconElement.textContent = 'dark_mode'
    } else {
      iconElement.textContent = 'light_mode'
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