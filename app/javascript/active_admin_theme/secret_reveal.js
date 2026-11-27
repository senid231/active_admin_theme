// Opt-in: add "active_admin_theme/secret_reveal" to ActiveAdminTheme.javascripts.
// A click on a [data-aat-secret-reveal] button requests data-url with fetch
// and shows the "value" of the JSON reply in place of the mask; a second click
// shows the mask again. The value is not kept: each reveal asks again.
// Without data-url the value is in a <template data-aat-secret-reveal-value>
// inside the root: a click shows its text, with no request.
const csrfToken = () => document.querySelector("meta[name=csrf-token]")?.content

const hide = (root, button) => {
  button.querySelector(".aat-secret-reveal-value").textContent = root.dataset.mask
  button.title = "Click to reveal"
  delete root.dataset.revealed
}

const show = (root, button, value) => {
  button.querySelector(".aat-secret-reveal-value").textContent = value
  button.title = "Click to hide"
  root.dataset.revealed = ""
}

const reveal = async (root, button) => {
  const template = root.querySelector(":scope > template[data-aat-secret-reveal-value]")
  if (template) return show(root, button, template.content.textContent)

  const error = root.querySelector(".aat-secret-reveal-error")
  error.hidden = true
  root.dataset.loading = ""
  try {
    const response = await fetch(root.dataset.url, {
      method: root.dataset.method || "GET",
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": csrfToken() || "",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    const data = await response.json()
    if (typeof data.value === "undefined" || data.value === null) throw new Error("no value in the reply")
    show(root, button, String(data.value))
  } catch (e) {
    error.textContent = `Could not load the value (${e.message})`
    error.hidden = false
  } finally {
    delete root.dataset.loading
  }
}

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-aat-secret-reveal] .aat-secret-reveal-toggle")
  if (!button) return
  const root = button.closest("[data-aat-secret-reveal]")
  if (root.dataset.loading !== undefined) return
  if (root.dataset.revealed !== undefined) hide(root, button)
  else reveal(root, button)
})
