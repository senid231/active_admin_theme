// Opt-in: add "active_admin_theme/lazy_load" to ActiveAdminTheme.javascripts.
// A [data-aat-lazy-load] element requests data-url with fetch when it first
// scrolls into view, or at once with data-eager, and replaces its content with
// the HTML of the reply. State is on the element: data-loading, then
// data-loaded or data-error (the message). Elements added later are picked up.
// A <script> in the reply does not run (innerHTML). The element dispatches a
// bubbling "aat:lazy-load:loaded" event after each load, and loads again on
// "aat:lazy-load:reload".
const SELECTOR = "[data-aat-lazy-load]"
const csrfToken = () => document.querySelector("meta[name=csrf-token]")?.content

const load = async (root) => {
  if (root.dataset.loading !== undefined) return
  observer.unobserve(root)
  delete root.dataset.loaded
  delete root.dataset.error
  root.dataset.loading = ""
  try {
    const response = await fetch(root.dataset.url, {
      method: root.dataset.method || "GET",
      credentials: "same-origin",
      headers: {
        Accept: "text/html",
        "X-CSRF-Token": csrfToken() || "",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    root.innerHTML = await response.text()
    root.dataset.loaded = ""
    root.dispatchEvent(new CustomEvent("aat:lazy-load:loaded", { bubbles: true }))
  } catch (e) {
    const message = document.createElement("span")
    message.className = "aat-lazy-load-error"
    message.setAttribute("role", "alert")
    message.textContent = `${root.dataset.errorText || "Could not load the content"} (${e.message})`
    root.replaceChildren(message)
    root.dataset.error = e.message
  } finally {
    delete root.dataset.loading
  }
}

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) load(entry.target)
  })
})

const seen = new WeakSet()
const watch = (root) => {
  if (seen.has(root)) return
  seen.add(root)
  if (root.dataset.eager !== undefined) load(root)
  else observer.observe(root)
}

const scan = (node) => {
  if (node.nodeType !== Node.ELEMENT_NODE) return
  if (node.matches(SELECTOR)) watch(node)
  node.querySelectorAll(SELECTOR).forEach(watch)
}

scan(document.body)
new MutationObserver((mutations) => {
  mutations.forEach((mutation) => mutation.addedNodes.forEach(scan))
}).observe(document.body, { childList: true, subtree: true })

document.addEventListener("aat:lazy-load:reload", (event) => {
  const root = event.target.closest?.(SELECTOR)
  if (root) load(root)
})
